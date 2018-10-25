export type Parser<T> = {
   (input: string, options?: any): T
}

export interface Location {
   offset: number
   line: number
   column: number
}

export type ExposedFunction = { type: 'function'; name: string }

export type ExposedType = { type: 'type'; name: string }

export type ExposedConstructor = { type: 'constructor'; name: string }

export type ExposedAll = { type: 'all' }

export type Exposed = ExposedAll | ExposedFunction | ExposedType | ExposedConstructor

export interface ImportStatement {
   type: 'import'
   location: Location
   module: string
   alias: string
   exposing: Exposed[]
}

export interface Module {
   type: 'module'
   location: Location
   module: string
   exposing: Exposed[]
   imports: ImportStatement[]
}

export const ModuleParser = loadParser<Module>('elm_module_parser')

function loadParser<T>(path: string): Parser<T> {
   return require(`../parsers/${path}`).parse
}