/**
 * Types for the `$jsonSchema` document validators passed to
 * `db.createCollection(..., { validator: ... })` and `collMod`.
 *
 * This is MongoDB's dialect of JSON Schema (draft 4 plus `bsonType`), not the
 * full JSON Schema spec. The keyword list below is deliberately closed: because
 * there is no index signature, TypeScript's excess-property check on object
 * literals reports misspelled keywords (`bsonTyp`, `requred`, ...) instead of
 * silently accepting a validator that never matches anything.
 *
 * Global by design - no top-level import/export, so mongosh scripts see these
 * without a module system mongosh cannot run.
 */

/** Values accepted by the `bsonType` keyword. See the MongoDB BSON type reference. */
type BsonTypeName =
  | "double"
  | "string"
  | "object"
  | "array"
  | "binData"
  | "undefined"
  | "objectId"
  | "bool"
  | "date"
  | "null"
  | "regex"
  | "dbPointer"
  | "javascript"
  | "symbol"
  | "javascriptWithScope"
  | "int"
  | "timestamp"
  | "long"
  | "decimal"
  | "minKey"
  | "maxKey"
  /** Matches int, long, double and decimal. */
  | "number";

/** The JSON Schema `type` keyword. Prefer `bsonType`, which is strictly more precise. */
type JsonSchemaTypeName =
  | "object"
  | "array"
  | "string"
  | "number"
  | "boolean"
  | "null";

interface MongoJsonSchema {
  // --- Metadata (ignored by the validator, kept for documentation) ---
  title?: string;
  description?: string;

  // --- Type ---
  bsonType?: BsonTypeName | readonly BsonTypeName[];
  type?: JsonSchemaTypeName | readonly JsonSchemaTypeName[];
  enum?: readonly any[];

  // --- Objects ---
  required?: readonly string[];
  properties?: Readonly<Record<string, MongoJsonSchema>>;
  patternProperties?: Readonly<Record<string, MongoJsonSchema>>;
  additionalProperties?: boolean | MongoJsonSchema;
  minProperties?: number;
  maxProperties?: number;
  dependencies?: Readonly<Record<string, MongoJsonSchema | readonly string[]>>;

  // --- Arrays ---
  items?: MongoJsonSchema | readonly MongoJsonSchema[];
  additionalItems?: boolean | MongoJsonSchema;
  minItems?: number;
  maxItems?: number;
  uniqueItems?: boolean;

  // --- Numbers ---
  minimum?: number;
  maximum?: number;
  exclusiveMinimum?: boolean;
  exclusiveMaximum?: boolean;
  multipleOf?: number;

  // --- Strings ---
  minLength?: number;
  maxLength?: number;
  pattern?: string;

  // --- Combinators ---
  allOf?: readonly MongoJsonSchema[];
  anyOf?: readonly MongoJsonSchema[];
  oneOf?: readonly MongoJsonSchema[];
  not?: MongoJsonSchema;
}

/**
 * A collection validator: either `{ $jsonSchema: ... }` or a plain query
 * expression (`{ price: { $gt: 0 } }`), which MongoDB also accepts.
 *
 * The `$jsonSchema?: never` on the query arm is load-bearing. Without it that
 * arm is just `Record<string, any>`, which matches every object literal, and a
 * `{ $jsonSchema: ... }` literal would then typecheck against it no matter how
 * malformed the schema was. Forbidding the key on the query arm leaves the
 * schema arm as the only candidate, so the schema is actually checked.
 */
type MongoValidator =
  | { $jsonSchema: MongoJsonSchema }
  // Compound validators: `{ $and: [ { $jsonSchema: ... }, { $expr: ... } ] }`
  // pairs a schema with a query predicate the schema dialect cannot express,
  // such as checking the byte length of a binData field.
  | { $and: readonly MongoValidator[] }
  | { $or: readonly MongoValidator[] }
  | { $nor: readonly MongoValidator[] }
  | (MongoQuery & {
      $jsonSchema?: never;
      $and?: never;
      $or?: never;
      $nor?: never;
    });
