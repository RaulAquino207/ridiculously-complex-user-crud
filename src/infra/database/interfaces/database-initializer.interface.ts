export interface DatabaseInitializer {
  initialize(): Promise<void>;
}

export const DATABASE_INITIALIZER_TOKEN = 'DATABASE_INITIALIZER';
