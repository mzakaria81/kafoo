// Provider-neutral response schema and local validator.
//
// Adapters may ask a provider to emit JSON, but the shape and the bounds are enforced here —
// never only by a prompt instruction, and never only by a provider-side schema that we have not
// measured. A reply that fails this validator never reaches a caller.

/// A deliberately small JSON-Schema subset. Enough for the shapes Kafoo actually returns; no
/// anyOf/oneOf/$ref/patternProperties, because a construct nobody needed is a construct nobody
/// tested.
export type ResponseSchema =
  | ObjectSchema
  | ArraySchema
  | StringSchema
  | IntegerSchema
  | NumberSchema
  | BooleanSchema;

interface SchemaCommon {
  readonly description?: string;
  /// When true, `null` is accepted in addition to the declared type. Nothing else changes.
  readonly nullable?: true;
}

export interface ObjectSchema extends SchemaCommon {
  readonly type: 'object';
  readonly properties: Readonly<Record<string, ResponseSchema>>;
  readonly required?: readonly string[];
}

export interface ArraySchema extends SchemaCommon {
  readonly type: 'array';
  readonly items: ResponseSchema;
}

export interface StringSchema extends SchemaCommon {
  readonly type: 'string';
  readonly enum?: readonly string[];
  readonly maxLength?: number;
}

export interface IntegerSchema extends SchemaCommon {
  readonly type: 'integer';
  readonly minimum?: number;
  readonly maximum?: number;
}

export interface NumberSchema extends SchemaCommon {
  readonly type: 'number';
  readonly minimum?: number;
  readonly maximum?: number;
}

export interface BooleanSchema extends SchemaCommon {
  readonly type: 'boolean';
}

/// Returns every problem found, empty when the value conforms. Paths are JSON-ish
/// (`basis.calories`, `ingredients[2]`) so a retry prompt can name exactly what was wrong.
export function validate(value: unknown, schema: ResponseSchema): string[] {
  return validateAt(value, schema, '');
}

function validateAt(value: unknown, schema: ResponseSchema, path: string): string[] {
  if (value === null) {
    if (schema.nullable === true) return [];
    return [`${label(path)}: expected ${schema.type}, got null`];
  }

  switch (schema.type) {
    case 'object':
      return validateObject(value, schema, path);
    case 'array':
      return validateArray(value, schema, path);
    case 'string':
      return validateString(value, schema, path);
    case 'integer':
      return validateInteger(value, schema, path);
    case 'number':
      return validateNumber(value, schema, path);
    case 'boolean':
      return validateBoolean(value, schema, path);
  }
}

function validateObject(
  value: unknown,
  schema: ObjectSchema,
  path: string,
): string[] {
  if (typeof value !== 'object' || Array.isArray(value)) {
    return [`${label(path)}: expected object, got ${describeType(value)}`];
  }

  const record = value as Record<string, unknown>;
  const errors: string[] = [];
  const required = new Set(schema.required ?? []);

  for (const key of required) {
    if (!(key in record)) {
      errors.push(`${joinPath(path, key)}: required property missing`);
    }
  }

  for (const key of Object.keys(record)) {
    const child = schema.properties[key];
    if (!child) {
      errors.push(`${joinPath(path, key)}: unexpected property "${key}"`);
      continue;
    }
    errors.push(...validateAt(record[key], child, joinPath(path, key)));
  }

  return errors;
}

function validateArray(
  value: unknown,
  schema: ArraySchema,
  path: string,
): string[] {
  if (!Array.isArray(value)) {
    return [`${label(path)}: expected array, got ${describeType(value)}`];
  }

  const errors: string[] = [];
  for (let i = 0; i < value.length; i++) {
    errors.push(...validateAt(value[i], schema.items, `${path}[${i}]`));
  }
  return errors;
}

function validateString(
  value: unknown,
  schema: StringSchema,
  path: string,
): string[] {
  if (typeof value !== 'string') {
    return [`${label(path)}: expected string, got ${describeType(value)}`];
  }

  const errors: string[] = [];
  if (schema.enum !== undefined && !schema.enum.includes(value)) {
    errors.push(
      `${label(path)}: ${JSON.stringify(value)} is not one of ${JSON.stringify([...schema.enum])}`,
    );
  }
  if (schema.maxLength !== undefined && value.length > schema.maxLength) {
    errors.push(
      `${label(path)}: string length ${value.length} is above the maximum ${schema.maxLength}`,
    );
  }
  return errors;
}

function validateInteger(
  value: unknown,
  schema: IntegerSchema,
  path: string,
): string[] {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return [`${label(path)}: expected integer, got ${describeType(value)}`];
  }
  if (!Number.isInteger(value)) {
    return [`${label(path)}: expected integer, got non-integer number ${value}`];
  }

  const errors: string[] = [];
  if (schema.minimum !== undefined && value < schema.minimum) {
    errors.push(`${label(path)}: ${value} is below the minimum ${schema.minimum}`);
  }
  if (schema.maximum !== undefined && value > schema.maximum) {
    errors.push(`${label(path)}: ${value} is above the maximum ${schema.maximum}`);
  }
  return errors;
}

function validateNumber(
  value: unknown,
  schema: NumberSchema,
  path: string,
): string[] {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return [`${label(path)}: expected number, got ${describeType(value)}`];
  }

  const errors: string[] = [];
  if (schema.minimum !== undefined && value < schema.minimum) {
    errors.push(`${label(path)}: ${value} is below the minimum ${schema.minimum}`);
  }
  if (schema.maximum !== undefined && value > schema.maximum) {
    errors.push(`${label(path)}: ${value} is above the maximum ${schema.maximum}`);
  }
  return errors;
}

function validateBoolean(
  value: unknown,
  schema: BooleanSchema,
  path: string,
): string[] {
  if (typeof value !== 'boolean') {
    return [`${label(path)}: expected boolean, got ${describeType(value)}`];
  }
  return [];
}

/// Parse text as JSON, then validate. A parse failure is an error string, never a thrown exception.
/// No regex extraction and no repair — a malformed reply is reported, not solved.
export function parseAndValidate(
  text: string,
  schema: ResponseSchema,
): { value: unknown } | { errors: string[] } {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return { errors: [`not valid JSON: ${message}`] };
  }

  const errors = validate(value, schema);
  if (errors.length > 0) return { errors };
  return { value };
}

function label(path: string): string {
  return path.length === 0 ? '(root)' : path;
}

function joinPath(parent: string, key: string): string {
  return parent.length === 0 ? key : `${parent}.${key}`;
}

function describeType(value: unknown): string {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (typeof value === 'number') {
    if (Number.isNaN(value)) return 'NaN';
    if (!Number.isFinite(value)) return String(value);
  }
  return typeof value;
}
