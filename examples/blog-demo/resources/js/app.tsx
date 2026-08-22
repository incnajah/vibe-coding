import { createInertiaApp } from '@inertiajs/react'
import { createRoot } from 'react-dom/client'

const appName = import.meta.env.VITE_APP_NAME || 'Laravel'

createInertiaApp({
    title: (title) => (title ? `${title} · ${appName}` : appName),
    resolve: (name) => {
        const pages = import.meta.glob('./Pages/**/*.tsx', { eager: true })
        const page = pages[`./Pages/${name}.tsx`]
        if (!page) throw new Error(`Inertia page not found: ./Pages/${name}.tsx`)
        return page
    },
    setup({ el, App, props }) {
        createRoot(el).render(<App {...props} />)
    },
    // A token, not a hex. audit-ui.sh flags raw hex as HIGH, and a bootstrap that
    // violates the design system it ships is a bad first commit.
    progress: { color: 'var(--color-primary)' },
})
