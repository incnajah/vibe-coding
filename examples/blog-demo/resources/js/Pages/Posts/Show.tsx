import { Head, Link } from '@inertiajs/react'
import { PublicLayout } from '@/Layouts/PublicLayout'
import { Badge } from '@/components/ui/Badge'
import { Prose } from '@/components/ui/Prose'

type Props = {
    post: {
        title: string
        excerpt: string | null
        paragraphs: string[]
        author: string | null
        publishedAt: string | null
        readingMinutes: number
    }
}

export default function Show({ post }: Props) {
    return (
        <PublicLayout>
            {/* Inertia renders client-side, so metadata is explicit or it ships empty. */}
            <Head>
                <title>{post.title}</title>
                {post.excerpt && <meta name="description" content={post.excerpt} />}
            </Head>

            <article className="mx-auto max-w-2xl">
                <Link
                    href="/"
                    className="rounded-sm text-sm text-content-muted outline-none transition-colors
                               hover:text-content focus-visible:ring-2 focus-visible:ring-primary
                               focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
                >
                    ← Semua tulisan
                </Link>

                <header className="mt-8 space-y-4">
                    <div className="flex flex-wrap items-center gap-2">
                        <Badge tone="accent">{post.readingMinutes} min baca</Badge>
                        {post.publishedAt && <Badge>{post.publishedAt}</Badge>}
                    </div>
                    <h1 className="text-2xl font-semibold tracking-tight text-balance text-content">
                        {post.title}
                    </h1>
                    {post.author && (
                        <p className="text-sm text-content-muted">oleh {post.author}</p>
                    )}
                </header>

                <hr className="my-8 border-border" />

                <Prose>
                    {post.paragraphs.map((paragraph, i) => (
                        <p key={i}>{paragraph}</p>
                    ))}
                </Prose>
            </article>
        </PublicLayout>
    )
}
