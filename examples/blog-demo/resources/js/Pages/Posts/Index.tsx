import { Head, Link, usePage } from '@inertiajs/react'
import { PublicLayout } from '@/Layouts/PublicLayout'
import { PageHeader } from '@/components/patterns/PageHeader'
import { EmptyState } from '@/components/patterns/EmptyState'
import { PostCard, type PostSummary } from '@/components/post/PostCard'

type Props = {
    posts: {
        data: PostSummary[]
        nextPageUrl: string | null
        prevPageUrl: string | null
    }
}

export default function Index({ posts }: Props) {
    const { site } = usePage<{ site: { title: string; tagline: string } }>().props

    return (
        <PublicLayout>
            <Head title={site.title} />

            <PageHeader
                eyebrow="Blog"
                title={site.title}
                description={site.tagline}
            />

            <div className="mt-12">
                {posts.data.length === 0 ? (
                    <EmptyState
                        title="Belum ada tulisan"
                        description="Artikel yang diterbitkan lewat panel admin akan muncul di sini."
                    />
                ) : (
                    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                        {posts.data.map((post) => (
                            <div key={post.slug} className="relative">
                                <PostCard post={post} />
                            </div>
                        ))}
                    </div>
                )}
            </div>

            {(posts.prevPageUrl || posts.nextPageUrl) && (
                <nav className="mt-12 flex justify-between" aria-label="Halaman">
                    <PageLink href={posts.prevPageUrl}>← Sebelumnya</PageLink>
                    <PageLink href={posts.nextPageUrl}>Berikutnya →</PageLink>
                </nav>
            )}
        </PublicLayout>
    )
}

function PageLink({ href, children }: { href: string | null; children: React.ReactNode }) {
    if (!href) {
        return <span className="text-sm text-content-muted opacity-50">{children}</span>
    }
    return (
        <Link
            href={href}
            preserveScroll
            className="rounded-sm px-3 py-2 text-sm font-medium text-primary outline-none
                       transition-colors hover:text-primary-hover focus-visible:ring-2
                       focus-visible:ring-primary focus-visible:ring-offset-2
                       focus-visible:ring-offset-surface"
        >
            {children}
        </Link>
    )
}
