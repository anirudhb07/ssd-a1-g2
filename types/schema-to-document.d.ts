/**
 * Derives a document type from a `$jsonSchema` validator, at the type level.
 *
 * This is what makes the checking self-updating: edit a validator in
 * `mongo/`, and the document type that `insertOne` is checked against changes
 * with it on the next keystroke. Nothing is generated, nothing is committed,
 * there is no build step - it is all resolved by the type checker.
 *
 * For it to work, the schema has to reach TypeScript as *literal* types
 * (`"object"`, not `string`), which is why the schemas in `mongo/` are written
 * as `const NameSchema = /** @type {const} *\/ ({ ... })`. Without that cast
 * TypeScript widens `required: ["id"]` to `string[]` and there is nothing left
 * to derive from.
 *
 * Global by design - no top-level import/export, so mongosh scripts see these
 * without a module system mongosh cannot run.
 */

// ---------------------------------------------------------------------------
// Scalars
// ---------------------------------------------------------------------------

/** Maps one `bsonType` name to the TypeScript type a document field holds. */
type BsonTypeToDocument<B> =
  B extends "string" ? string :
  B extends "int" | "long" | "double" | "decimal" | "number" ? number :
  B extends "bool" ? boolean :
  B extends "date" ? Date :
  B extends "objectId" ? ObjectId :
  B extends "binData" ? BinData | UUID :
  B extends "timestamp" ? Timestamp :
  B extends "regex" ? RegExp :
  B extends "null" ? null :
  B extends "minKey" ? MinKey :
  B extends "maxKey" ? MaxKey :
  B extends "javascript" | "javascriptWithScope" ? Function :
  B extends "object" ? Record<string, unknown> :
  B extends "array" ? readonly unknown[] :
  unknown;

// ---------------------------------------------------------------------------
// Tuple building, for `minItems === maxItems`
// ---------------------------------------------------------------------------

/**
 * Builds `[T, T, ...]` of length `N`. A schema that pins `minItems` and
 * `maxItems` to the same number describes a fixed-length array, so deriving a
 * tuple preserves the arity check - GeoJSON `coordinates` being the case that
 * matters here.
 */
type TupleOf<T, N extends number, Acc extends unknown[] = []> =
  Acc["length"] extends N ? Acc : TupleOf<T, N, [...Acc, T]>;

// ---------------------------------------------------------------------------
// Object property handling
// ---------------------------------------------------------------------------

type SchemaProperties<S> = S extends { properties: infer P } ? P : {};

/** The `required: [...]` array as a union of key names. */
type SchemaRequiredKeys<S> =
  S extends { required: readonly (infer R)[] } ? Extract<R, string> : never;

/**
 * A schema is treated as closed unless it opts out with
 * `additionalProperties: true`.
 *
 * This is stricter than MongoDB, where an absent `additionalProperties` means
 * extra fields are accepted. Closing it by default is the entire reason a
 * misspelled field name (`search_location` for `location`) is a compile error
 * rather than a document that fails validation in production. Opting a
 * collection back open is a one-word edit to its validator, and the type
 * follows automatically.
 */
type SchemaExtraProperties<S> =
  S extends { additionalProperties: true } ? { [key: string]: unknown } : {};

/** Collapses an intersection into a single object type, so hovers stay readable. */
type Flatten<T> = T extends infer U ? { [K in keyof U]: U[K] } : never;

type ObjectFromSchema<S> = Flatten<
  {
    -readonly [K in Extract<keyof SchemaProperties<S>, SchemaRequiredKeys<S>>]:
      DocumentOf<SchemaProperties<S>[K]>;
  } & {
    -readonly [K in Exclude<keyof SchemaProperties<S>, SchemaRequiredKeys<S>>]?:
      DocumentOf<SchemaProperties<S>[K]>;
  } & SchemaExtraProperties<S>
>;

// ---------------------------------------------------------------------------
// Array handling
// ---------------------------------------------------------------------------

type ArrayFromSchema<S> =
  S extends { items: infer I }
    ? I extends readonly any[]
      // Tuple form: `items: [schemaA, schemaB]` positionally types each slot.
      ? { -readonly [K in keyof I]: DocumentOf<I[K]> }
      // `infer N` cannot be referenced from a sibling property in the same
      // object pattern, so the two bounds are matched in separate steps.
      : S extends { minItems: infer N extends number }
        ? S extends { maxItems: N }
          ? TupleOf<DocumentOf<I>, N>
          : DocumentOf<I>[]
        : DocumentOf<I>[]
    : unknown[];

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/**
 * Turns a `$jsonSchema` node into the type of the value it validates.
 *
 * Order matters: `enum` is checked before `bsonType`, because a schema may
 * carry both and the enum is the narrower statement of the two.
 */
type DocumentOf<S> =
  // `enum: ["Point"]` -> the literal union "Point"
  S extends { enum: readonly (infer E)[] } ? E :
  S extends { bsonType: "object" } ? ObjectFromSchema<S> :
  S extends { bsonType: "array" } ? ArrayFromSchema<S> :
  // A union of bson types (`bsonType: ["string", "null"]`) distributes.
  S extends { bsonType: readonly (infer B)[] } ? BsonTypeToDocument<B> :
  S extends { bsonType: infer B } ? BsonTypeToDocument<B> :
  // No `bsonType`, but shaped like an object or array anyway.
  S extends { properties: any } ? ObjectFromSchema<S> :
  S extends { items: any } ? ArrayFromSchema<S> :
  // `{}` - an empty schema constrains nothing.
  unknown;

/**
 * The document type for a whole collection: the schema's shape plus the `_id`
 * the server fills in when it is not supplied.
 */
type CollectionDocumentOf<S> = Flatten<{ _id?: any } & ObjectFromSchema<S>>;

// ---------------------------------------------------------------------------
// Keyword validation
// ---------------------------------------------------------------------------

/**
 * Collects every key in a schema that is not a known `$jsonSchema` keyword.
 *
 * `/** @type {const} *\/` buys literal types but costs excess-property
 * checking: a const-asserted object passed to `createCollection` is no longer
 * a *fresh* literal, so TypeScript stops reporting unknown keys there. This
 * recovers that check - `AssertSchemaKeywords` below turns a leftover key into
 * a compile error naming the offender.
 *
 * Recursion deliberately descends into `properties` *values* but not their
 * keys: those keys are the document's field names, not schema keywords.
 */
type UnknownSchemaKeywords<S> =
  | Exclude<keyof S, keyof MongoJsonSchema>
  | (S extends { properties: infer P }
      ? { [K in keyof P]: UnknownSchemaKeywords<P[K]> }[keyof P]
      : never)
  | (S extends { items: infer I }
      ? I extends readonly any[]
        ? { [K in keyof I]: UnknownSchemaKeywords<I[K]> }[number]
        : UnknownSchemaKeywords<I>
      : never)
  | (S extends { allOf: readonly (infer A)[] } ? UnknownSchemaKeywords<A> : never)
  | (S extends { anyOf: readonly (infer A)[] } ? UnknownSchemaKeywords<A> : never)
  | (S extends { oneOf: readonly (infer A)[] } ? UnknownSchemaKeywords<A> : never);

/**
 * Fails to compile unless `T` is `never`, reporting the offending member:
 *
 *     Type '"requred"' does not satisfy the constraint 'never'.
 *
 * Instantiate it with a concrete schema (see `SchemaKeywordChecks` in
 * types/collections.d.ts) - the constraint is verified where the type argument
 * is supplied, so it has to be applied to a real `typeof ...Schema`, not
 * wrapped in another generic alias. Wrapping defers the argument, and a
 * constraint that is still generic gets checked against the *declaration*
 * rather than the schema, which either never fires or fails outright.
 */
type ExpectNever<T extends never> = T;
