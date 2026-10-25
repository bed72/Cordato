# dart-primary-constructor-conventions Specification

> Convenções vigentes e suas exceções estão em AGENTS.md na raiz; esta spec não
> autoriza mudanças de ownership ou construtores vazios em interfaces/mixins.
> Consulte [a referência atual](../../README.md).

## Purpose
Define the Dart compatibility, eligibility, contract-preservation, architectural, documentation, and validation conventions for adopting primary constructors in Cordato.

## Requirements

### Requirement: Dart language compatibility
The Cordato project MUST declare a Dart SDK lower bound of 3.13 or newer before source files use primary constructor syntax, and the syntax MUST NOT depend on an experimental language flag.

#### Scenario: Resolving the project with a supported SDK
- **WHEN** dependencies are resolved with Dart 3.13 or newer within the range declared by `pubspec.yaml`
- **THEN** source files containing primary constructors are accepted as standard Dart syntax
- **THEN** no experiment flag or additional package is required

#### Scenario: Attempting to use an unsupported SDK
- **WHEN** a contributor attempts to resolve the project with Dart 3.12 or older
- **THEN** the SDK constraint rejects that environment before application source is compiled

### Requirement: Eligibility for primary constructors
New classes, mixin classes, and enums SHALL prefer a primary constructor when they have one canonical generative construction path and the constructor primarily declares instance fields or forwards super parameters. This focused migration SHALL convert every eligible existing declaration under `lib/`; after the baseline migration, existing declarations SHALL be converted when already being changed or explicitly selected for another focused migration.

#### Scenario: Creating a simple immutable widget
- **WHEN** a new widget receives constructor parameters that are stored unchanged as final fields and optionally forwards `key` to its superclass
- **THEN** the widget uses a constant primary constructor when all instance state permits const construction
- **THEN** declaring parameters use explicit types and `final`

#### Scenario: Creating a simple dependency implementation
- **WHEN** a new concrete class receives a dependency and only stores it for later use
- **THEN** the dependency can be declared as a final field in the primary constructor header
- **THEN** the class does not repeat an equivalent field declaration and traditional constructor solely for assignment

#### Scenario: Encountering an unchanged traditional constructor
- **WHEN** a traditional constructor is outside a focused migration's selected source scope or is ineligible under the documented matrix
- **THEN** it is not converted solely to make the repository syntactically uniform

#### Scenario: Completing the baseline migration
- **WHEN** this adoption change inventories existing declarations under `lib/`
- **THEN** every eligible constructor is converted, not only the initial pilot declarations
- **THEN** each retained traditional constructor has a concrete eligibility, semantics, or readability reason

### Requirement: Constructor contract preservation
Converting a traditional constructor to a primary constructor MUST preserve its externally observable contract, including constructor name, visibility, parameter names, requiredness, types, nullability, default values, const availability, super forwarding, and invocation behavior.

#### Scenario: Converting an unnamed constructor used by dependency injection
- **WHEN** an unnamed traditional constructor referenced as `Type.new` is converted
- **THEN** the resulting primary constructor remains unnamed with an equivalent function signature
- **THEN** existing DI registrations and direct call sites require no change

#### Scenario: Converting a named private constructor
- **WHEN** a named private generative constructor is selected for conversion
- **THEN** the primary constructor retains the same private name
- **THEN** factories, static creation methods, redirects, and internal call sites continue to use the same construction path

#### Scenario: Converting a const constructor
- **WHEN** a traditional const constructor is converted
- **THEN** const construction remains available at every existing call site
- **THEN** every induced instance field remains final and valid for constant evaluation

#### Scenario: Reviewing a conversion-only diff
- **WHEN** a file is changed only to adopt primary constructor syntax
- **THEN** no parameter, field, method, control flow, formatting outside the declaration, or runtime behavior is added, removed, or reordered without a separate requirement

### Requirement: Declaring and non-declaring parameters
A primary constructor MUST use `final` for immutable induced fields, `var` only for intentionally mutable induced fields, and an unmodified typed parameter when the value is needed only during initialization and must not become an instance field.

#### Scenario: Storing immutable input
- **WHEN** a primary constructor input represents immutable instance state
- **THEN** it is declared with `final` and induces exactly one final field

#### Scenario: Using transient initialization input
- **WHEN** a constructor input is used to derive another field but is not part of instance state
- **THEN** the parameter has an explicit type without `final` or `var`
- **THEN** no field is induced for that input

#### Scenario: Forwarding a superclass parameter
- **WHEN** a value only needs to be passed to a superclass constructor
- **THEN** a super parameter is used where it preserves the existing superclass call and signature

### Requirement: Complex construction remains explicit
Factories, redirecting constructors, multiple generative construction paths, initializer lists, assertions, constructor bodies, and asynchronous command setup MUST be reviewed manually. Primary constructor syntax SHALL be used in these cases only when it remains legal and at least as clear as the traditional form.

#### Scenario: Class exposes factories
- **WHEN** a class uses factory constructors to select concrete implementations
- **THEN** those factories remain in the class body
- **THEN** converting the canonical generative constructor does not change factory selection or return types

#### Scenario: Class exposes a redirecting constructor
- **WHEN** an in-body constructor redirects to the canonical generative constructor
- **THEN** the redirect remains explicit and targets the same constructor after any conversion

#### Scenario: Constructor performs non-trivial initialization
- **WHEN** a constructor initializes multiple command objects, subscribes to a stream, mutates late fields, validates with assertions, or executes a body
- **THEN** the implementation is reviewed for initializer and body scope semantics
- **THEN** the traditional constructor is retained when it communicates lifecycle or ordering more clearly

#### Scenario: Type has multiple non-redirecting generative constructors
- **WHEN** a class must retain more than one non-redirecting generative constructor
- **THEN** it does not adopt a primary constructor that would make the required construction paths illegal

### Requirement: No-value conversions are avoided
The codebase MUST NOT add primary constructors to constructor-free interfaces, ordinary mixins, extensions, private `State` classes, test mocks, or classes relying on an implicit empty constructor solely for stylistic consistency.

#### Scenario: Reviewing a constructor-free declaration
- **WHEN** a declaration has no constructor parameters or assignment boilerplate to remove
- **THEN** it remains constructor-free unless an independent behavior or visibility requirement needs an explicit constructor

#### Scenario: Reviewing a StatefulWidget implementation
- **WHEN** the `StatefulWidget` has immutable input fields but its associated `State` class has no constructor inputs
- **THEN** the widget can use a primary constructor when eligible
- **THEN** no explicit primary constructor is added to the `State` class

### Requirement: Architectural neutrality
Primary constructor adoption MUST remain a syntax-level refactoring and MUST NOT change dependency direction, feature ownership, state management, domain invariants, routes, module registrations, external service access, or persistence behavior.

#### Scenario: Converting a repository or command-related declaration
- **WHEN** a constructor in domain, data, infrastructure, or presentation is converted
- **THEN** all imports and layer dependencies remain compliant with the existing Cordato architecture
- **THEN** no SDK access or business rule moves between layers

#### Scenario: Converting financial code
- **WHEN** an eligible declaration belongs to expense or budget
- **THEN** money remains represented as integer BRL cents
- **THEN** ownership, date-derived budget membership, and non-overlap invariants remain unchanged

### Requirement: Convention documentation and validation
The project SHALL document the eligibility rules, exclusions, Dart version requirement, and contract-preservation rules in its contributor guidance. Every focused migration SHALL be formatted and pass static analysis and the relevant existing automated tests.

#### Scenario: Implementing the convention
- **WHEN** the adoption change is completed
- **THEN** the contributor guidance describes when primary constructors are preferred and when traditional constructors remain appropriate
- **THEN** examples follow the project's class modifiers, const, import, widget, and architecture conventions

#### Scenario: Validating converted declarations
- **WHEN** one or more existing constructors are converted
- **THEN** the changed Dart files are formatted
- **THEN** `flutter analyze` completes without diagnostics caused by the conversion
- **THEN** existing non-UI tests relevant to converted domain, data, infrastructure, or command code continue to pass

#### Scenario: Validating presentation-only conversion
- **WHEN** only widget or screen constructor syntax changes without behavior changes
- **THEN** no Flutter widget test is added solely for the syntax refactoring
- **THEN** existing visual or Maestro validation remains unchanged unless a separate UI behavior change requires it
