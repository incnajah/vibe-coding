import { Link, usePage } from '@inertiajs/react'

type SharedSite = { site: { title: string; tagline: string; showAuthor: boolean } }

export function PublicLayout({ children }: { children: React.ReactNode }) {
    const { site } = usePage<SharedSite>().props

    return (
        <div className="min-h-screen bg-surface font-sans text-content antialiased">
            <header className="border-b border-border">
                <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
                    <Link
                        href="/"
                        className="rounded-sm text-sm font-semibold tracking-tight outline-none
                                   transition-colors hover:text-primary focus-visible:ring-2
                                   focus-visible:ring-primary focus-visible:ring-offset-2
                                   focus-visible:ring-offset-surface"
                    >
                        {site.title}
                    </Link>
                    <a
                        href="/admin"
                        className="rounded-sm px-3 py-2 text-sm text-content-muted outline-none
                                   transition-colors hover:text-content focus-visible:ring-2
                                   focus-visible:ring-primary focus-visible:ring-offset-2
                                   focus-visible:ring-offset-surface"
                    >
                        Admin
                    </a>
                </div>
            </header>

            <main className="mx-auto max-w-5xl px-6 py-12">{children}</main>

            <footer className="border-t border-border">
                <div className="mx-auto max-w-5xl px-6 py-8 text-xs text-content-muted">
                    Dibangun dengan Laravel, Filament, Inertia dan React.
                </div>
            </footer>
        </div>
    )
}
