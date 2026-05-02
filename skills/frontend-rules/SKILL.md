---
name: frontend-rules
description: Frontend engineering standards with strict priority chain — Security → Performance → Best Practices. React 19, TypeScript strict, Vinxi, TanStack Router, Tailwind CSS 4, shadcn/ui, Atomic Design, Zod, React Hook Form.
---

# Frontend Engineering Standards

> **Priority chain: Security → Performance → Best Practices.** Every decision follows this order.

## 1. Security (top priority)

### Authentication (CRITICAL — non-negotiable)

- **Tokens NEVER in browser JS** — httpOnly cookies via Vinxi/h3 server handlers
- **NO `localStorage` / `sessionStorage`** for tokens, secrets, or sensitive data
- **NO `keycloak-js`** — auth flow 100% server-side (Authorization Code + PKCE)
- Cookie config: `httpOnly: true`, `sameSite: "strict"`, `secure: true` (production)
- Cookie isolation between apps: `client_access_token` vs `backoffice_access_token`
- Token refresh server-side only (`/auth/refresh` endpoint)
- Session restoration via `/auth/me` with auto-refresh

### XSS Prevention

- **NEVER** `dangerouslySetInnerHTML` without DOMPurify sanitization
- Never interpolate user data into raw HTML
- CSP headers configured server-side

### Input Validation

- All user inputs validated via **Zod schemas**
- Schemas mirror backend validation rules (Keycloak password policy, CPF/CNPJ algorithms)
- Validate client-side for UX, but NEVER trust client validation alone

### Route Security

- Protected routes via `authenticatedRoute` wrapper (TanStack Router)
- AuthGuard component for route-level access control
- Redirect to login on auth failure

## 2. Performance (second priority)

### React rendering

- **Memoization**: `useMemo` / `useCallback` only when measured or obvious:
  - Heavy computation in render
  - Large lists / tables
  - Stable reference needed for child components
- **Lazy loading**: `React.lazy` + `Suspense` for route-level code splitting
- **Virtualization**: `@tanstack/react-virtual` for lists > 100 items
- **Stable keys**: never use array index as key on dynamic lists
- **Stable references**: avoid creating objects/functions in JSX props

### Bundle & assets

- Named imports only: `import { Button } from '...'` (not `import *`)
- Images: `loading="lazy"`, modern formats (WebP/AVIF), proper `width`/`height`
- Fonts: preload critical fonts, `font-display: swap`

### State

- Avoid unnecessary re-renders:
  - Split large Context providers into smaller ones
  - Use selectors pattern when state grows
- **Derived state**: compute inline or `useMemo` — NEVER `useState` + `useEffect`
- **Form state**: React Hook Form handles internally (no manual `useState` per field)

## 3. Best Practices (third priority)

### The golden rule

> **Never refactor for aesthetics.** Every change must be justified by security fix, performance gain, or actual bug.

### TypeScript

- **Strict mode always** (`"strict": true` in tsconfig)
- **Zero `any`** — explicit or implicit
  - Use `unknown` + type narrowing
  - Use generics when type varies
  - Last resort: `// @ts-expect-error` with explanation comment
- Prefer **types** for shapes, **interfaces** for extensible objects
- Discriminated unions for state machines:

```ts
type AuthState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'authenticated'; user: User }
  | { status: 'error'; error: string };
```

### Atomic Design (component architecture)

| Level | Responsibility | Examples |
|---|---|---|
| **atoms** | Smallest UI element, single purpose | ProfileBadge, ThemeToggle, StatusDot |
| **molecules** | Composition of atoms with behavior | LoginForm, PasswordField, SearchBar |
| **organisms** | Complex sections, may fetch data | Header, Sidebar, EmployeeTable |
| **templates** | Page layouts, slot-based | AppLayout, AuthLayout |
| **pages** | Route components, orchestrate organisms | DashboardPage, ProfilePage |
| **guards** | Route protection logic | AuthGuard |
| **ui** | shadcn/ui primitives (untouched) | Button, Card, Dialog, Table |

Rules:
- **< 150 lines** per component — extract sub-components if exceeded
- Props type at top of file, always exported
- Business logic in **custom hooks** or **services**, never in component
- Component does: render, UI events, composition. That's it.
- **Check existing components** before creating new ones

### Routing — TanStack Router

- Route tree in `router.tsx` — explicit hierarchy
- Type registration: `declare module '@tanstack/react-router'`
- Route guards via `authenticatedRoute` parent
- Search params validated with Zod: `validateSearch: z.object(...)`
- `notFoundComponent` on rootRoute
- Type-safe navigation: `<Link to="/profile" />` with autocomplete

### Forms — React Hook Form + Zod

```tsx
// Schema in separate file: schemas/employee.ts
const schema = z.object({
  name: z.string().min(2),
  cpf: z.string().refine(validateCpf, "CPF inválido"),
  email: z.string().email(),
});

// Component uses resolver
const form = useForm<z.infer<typeof schema>>({
  resolver: zodResolver(schema),
});
```

- Schemas in dedicated files: `schemas/auth.ts`, `schemas/employee.ts`
- Real validations (CPF/CNPJ modulo 11 algorithm, not just regex)
- Password schema mirrors Keycloak policy
- Schemas shared between client/backoffice when same domain

### State Management

| Type | Solution |
|---|---|
| **Auth state** | React Context (`AuthProvider` + `useAuth()`) |
| **Server state** | API layer hooks (dedicated hooks per endpoint) |
| **Form state** | React Hook Form (internal state) |
| **Local UI state** | `useState` / `useReducer` |
| **Derived state** | `useMemo` or compute inline |
| **Theme** | `next-themes` (dark/light toggle) |

No Redux, no Zustand — scope doesn't justify external state lib.

### Styling — Tailwind CSS 4 + shadcn/ui

- **Tailwind CSS 4** with `@theme inline` for design tokens
- **Design tokens via CSS variables** with oklch color space:
  ```css
  :root { --primary: oklch(0.205 0 0); }
  .dark { --primary: oklch(0.985 0 0); }
  ```
- **shadcn/ui** for primitives — don't modify ui/ components directly
- **Inline styles prohibited** (except truly dynamic computed values)
- **class-variance-authority** for component variants
- **tailwind-merge** (`cn()` utility) for class merging

### Accessibility (a11y) — non-negotiable

- **Semantic HTML first**: `<button>`, `<nav>`, `<main>`, `<form>` before `<div>`
- `aria-*` only when semantic HTML isn't enough
- **Visible focus** always (never remove outline without replacement)
- **Logical tab order**, no positive `tabIndex`
- **WCAG AA contrast** minimum (4.5:1 normal text)
- **Labels** associated to inputs (`<label htmlFor>` or `aria-label`)
- **Live regions**: `aria-live="polite"` for errors, `"assertive"` for critical
- **Images with alt** (empty alt if decorative)
- Radix UI provides built-in a11y — leverage it

### Explicit States

Every component that fetches data MUST render 4 states:

```tsx
function EmployeeList() {
  const { data, isPending, isError, error } = useEmployees();

  if (isPending) return <EmployeesSkeleton />;
  if (isError) return <ErrorState error={error} />;
  if (data.length === 0) return <EmptyState />;
  return <EmployeesTable employees={data} />;
}
```

### i18n Readiness

Currently no `react-i18next` — but prepare for it:
- **No hardcoded strings in JSX** — use named constants or data objects
- Dates via `Intl.DateTimeFormat`, currency via `Intl.NumberFormat`
- When i18n is added: `t('key')` pattern, keys by feature: `auth.login.title`

## 4. Testing (MANDATORY — zero negotiation)

### Stack

| Tool | Purpose |
|---|---|
| **Vitest** | Unit + component tests |
| **Testing Library** (React) | Component rendering |
| **Testing Library** (user-event) | User interaction |
| **Playwright** | E2E tests |

### Rules

- **Todo componente/hook novo DEVE ter teste** — sem exceção
- **Cobertura ≥ 80% SEMPRE** — gate inviolável
  - Run: `npm test -- --coverage`
  - If < 80%: task NOT delivered. Write more tests.
  - Report exact coverage number
- Test **behavior**, not implementation
- Queries by **role** or **label**, never by className (test-id as last resort)
- Naming: `it('shows error toast when login fails')`
- Setup in `test-utils.tsx` with providers (Router, Auth, Theme)

```tsx
// ✓ Good — testing behavior
it('disables submit while form is submitting', async () => {
  render(<LoginForm />);
  await user.type(screen.getByLabelText('Email'), 'a@b.com');
  await user.click(screen.getByRole('button', { name: /entrar/i }));
  expect(screen.getByRole('button', { name: /entrar/i })).toBeDisabled();
});

// ✗ Bad — testing implementation
it('sets isLoading to true', () => {
  const { result } = renderHook(useLogin);
  expect(result.current.isLoading).toBe(false);
});
```

### Scripts

```bash
npm test           # vitest run
npm run test:watch # vitest watch
npm run test:e2e   # playwright
npm run lint       # eslint --max-warnings 0
npm run typecheck  # tsc --noEmit
```

> **Código sem teste = código que não existe. Cobertura < 80% = task não entregue.**

## Anti-patterns (instant FAIL)

| Pattern | Why bad | Fix |
|---|---|---|
| `any` explicit | Breaks types | `unknown` + narrowing |
| `localStorage` for tokens | XSS surface | httpOnly cookies server-side |
| `keycloak-js` | Exposes tokens | Server-side auth flow |
| `dangerouslySetInnerHTML` | XSS | DOMPurify or Markdown lib |
| `useEffect([]) + fetch` | Race conditions | Dedicated hook / API layer |
| `useState` + `useEffect` derived | Cascade bugs | `useMemo` or compute inline |
| Inline styles | Not theme-aware | Tailwind / CSS vars |
| Hardcoded strings in JSX | Blocks i18n | Named constants |
| `tabIndex={1}+` | Breaks tab order | No tabIndex (or `0`/`-1`) |
| Test `state.isLoading` | Couples to impl | Test UI behavior |
| `as any` cast | Lies about types | Type guard |
| Component > 150 lines | Unmaintainable | Extract sub-components |
| New component without checking existing | Duplication | Check Atomic Design tree first |
| Refactor "for beauty" | Wasted effort | Only if security/perf/bug |
| `fetch` in component | No error/loading handling | API layer hook |
