# Forem Copilot Instructions

## Project Overview
Forem is an open-source Ruby on Rails application for building online communities, powering platforms like dev.to. The codebase emphasizes community features, content management, and social interactions.

## Tech Stack
- **Backend**: Ruby on Rails (Rails framework)
- **Frontend**: Transitioning to Preact-first architecture
- **Database**: PostgreSQL
- **Background Jobs**: Sidekiq
- **Asset Pipeline**: esbuild, Babel
- **Testing**: RSpec (backend), Jest/Cypress (frontend)

## Code Conventions

### Ruby/Rails
- Follow Ruby style guide and Rails conventions
- Use service objects for complex business logic (in `app/services/`)
- Use query objects for complex database queries (in `app/queries/`)
- Prefer `destroy` over `delete` to trigger callbacks and maintain referential integrity
- Use strong parameters and sanitizers for user input
- Keep controllers thin - delegate to service objects or models

### Testing
- Write RSpec tests for Ruby code
- Test coverage is important - ensure new features have tests
- Use factories for test data, not fixtures

### Naming
- Service classes: verb-based names (e.g., `Users::DeleteActivity`)
- Query classes: descriptive of what they query (e.g., `ArticleFinder`)
- Use namespaces to organize related functionality

### Project Structure
- `app/services/` - Business logic and operations
- `app/queries/` - Database query objects
- `app/workers/` - Background job workers
- `app/policies/` - Authorization policies
- `app/serializers/` - JSON serialization
- `app/liquid_tags/` - Custom Liquid tag implementations

## Domain Concepts
- **Articles**: Main content type (blog posts, tutorials)
- **Comments**: Threaded discussions on articles
- **Users**: Community members with profiles
- **Organizations**: Group accounts
- **Reactions**: Emoji-based engagement (hearts, unicorns, etc.)
- **Notifications**: User activity alerts
- **Tags**: Content categorization

## Key Principles
- Community safety and moderation features are critical
- Performance matters - this serves high-traffic communities
- Accessibility and internationalization (i18n) support
- AGPL v3 licensed - open source community project

## Common Patterns
- Callbacks trigger notifications and related updates
- Background jobs handle async work (emails, notifications)
- Strong use of ActiveRecord associations and callbacks
- Counter caches for performance on aggregated counts

## What to Avoid
- Direct database deletions that skip callbacks
- Exposing sensitive user data
- Breaking existing API contracts
- Bypassing authorization policies
- Hardcoded strings that should be internationalized
