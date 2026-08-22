import { Link, usePage } from '@inertiajs/react'
import { Badge } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'

export type PostSummary = {
    slug: string
    title: string
    excerpt: string | null
    author: string | null
    publishedAt: string | null
    readingMinutes: number
}

export function PostCard({ post }: { post: PostSummary }) {
    const { site } = usePage<{ site: { showAuthor: boolean } }>().props

    return (
        <Card className="group h-full">
            <article className="flex h-full flex-col gap-3 p-6">
                <div className="flex items-center gap-2">
                    <Badge tone="accent">{post.readingMinutes} min baca</Badge>
                    {post.publishedAt && <Badge>{post.publishedAt}</Badge>}
                </div>

                <h2 className="text-lg font-semibold tracking-tight text-content">
                    {/* The whole card is clickable via this link, not a div with onClick —
                        a div is not keyboard reachable and has no role. */}
                    <Link
                        href={`/posts/${post.slug}`}
                        className="rounded-sm underline-offset-4 outline-none transition-colors
                                   group-hover:text-primary focus-visible:ring-2 focus-visible:ring-primary
                                   focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
                    >
                        <span className="absolute inset-0" aria-hidden />
                        {post.title}
                    </Link>
                </h2>

                {post.excerpt && (
                    <p className="line-clamp-3 text-sm text-content-muted">{post.excerpt}</p>
                )}

                {site.showAuthor && post.author && (
                    <p className="mt-auto pt-3 text-xs text-content-muted">oleh {post.author}</p>
                )}
            </article>
        </Card>
    )
}
