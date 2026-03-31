# Project Name

> Replace this with your project's one-line description.

## Overview

Describe what this project does and why it exists. Include the key problem it solves and who it's for.

## Tech Stack

- **Runtime:** Node.js / Python / Go
- **Framework:** Express / Next.js / FastAPI
- **Database:** PostgreSQL / MongoDB / Supabase
- **Auth:** JWT / OAuth / Supabase Auth
- **Hosting:** Vercel / AWS / Railway

## Phase 1: Core Foundation

### Module 1.1: Project Scaffold

- Set up project structure with TypeScript
- Configure ESLint, Prettier, and testing framework
- Create development and production configurations
- Set up CI/CD pipeline

### Module 1.2: Database & Models

- Design database schema
- Create migration files
- Implement data access layer
- Add seed data for development

### Module 1.3: Authentication

- Implement user registration
- Implement login/logout
- Add JWT token management
- Create auth middleware
- Add rate limiting

## Phase 2: Core Features

### Module 2.1: Feature A

- Requirement 1 with specific acceptance criteria
- Requirement 2 with specific acceptance criteria
- API endpoint: `POST /api/feature-a`
- UI component: Dashboard view with data table

### Module 2.2: Feature B

- Requirement 1
- Requirement 2
- Depends on: Module 2.1 (uses Feature A's data model)

## Phase 3: Polish & Launch

### Module 3.1: Error Handling & Edge Cases

- Global error boundary
- API error responses
- Input validation
- Loading states

### Module 3.2: Testing & Documentation

- Unit tests for all business logic
- Integration tests for API endpoints
- API documentation
- User guide

---

## Tips for Writing Specs

1. **Be specific**: "Users can upload CSV files up to 10MB" is better than "File upload feature"
2. **Define acceptance criteria**: Each module should have testable boolean statements
3. **Map dependencies**: Which modules depend on others? Phase 1 should have no cross-module dependencies
4. **Think in phases**: Foundation → Features → Polish. Each phase should be independently valuable
5. **Include verification**: How will you know each module works? Describe the test or demo
