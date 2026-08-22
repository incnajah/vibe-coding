# ERD

```mermaid
erDiagram
    USERS ||--o{ POSTS : writes

    USERS {
        id bigint PK
        name string
        email string UK
        password string
        is_admin boolean
    }
    POSTS {
        id bigint PK
        user_id bigint FK
        title string
        slug string UK
        excerpt string NULL
        body text
        published_at timestamp NULL
        created_at timestamp
        updated_at timestamp
    }
```

- `slug` unik dan berindeks — dipakai sebagai URL publik.
- `published_at` null berarti draft. Tanggal, bukan boolean, supaya urutan terbit
  bisa diketahui dan penjadwalan mungkin ditambahkan tanpa migrasi.
- `user_id` berindeks dengan `onDelete('cascade')`.
