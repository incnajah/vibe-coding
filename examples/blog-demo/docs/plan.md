# Build plan

- [ ] Slice 1 — Posts
      migration + model + factory + seeder
      Actions: CreatePost, UpdatePost, PublishPost, UnpublishPost
      Query: PublishedPosts
      Pest: draft tidak bocor, publish menstempel tanggal, slug unik
      Filament: PostResource + aksi publish/unpublish
      Inertia: halaman daftar `/` dan detail `/posts/{slug}`
      Acceptance: verify.sh hijau, `/` 200, artikel draft tidak terlihat
