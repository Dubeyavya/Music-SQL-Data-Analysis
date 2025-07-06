SELECT * FROM "Album";

SELECT * FROM "Artist";

SELECT * FROM "Customer";

SELECT * FROM "Employee";

SELECT * FROM "Genre";

SELECT * FROM "Invoice";

SELECT * FROM "Invoice_line";

SELECT * FROM "Media_type";

SELECT * FROM "playlist";

SELECT * FROM "playlist_track";

SELECT * FROM "track";

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE';


-- 1. "Album" → "Artist"
ALTER TABLE "Album"
ADD CONSTRAINT fk_album_artist
FOREIGN KEY ("artist_id")
REFERENCES "Artist" ("artist_id");

-- 2. "Customer" → "Employee" (support_rep_id refers to employee_id)
ALTER TABLE "Customer"
ADD CONSTRAINT fk_customer_employee
FOREIGN KEY ("support_rep_id")
REFERENCES "Employee" ("employee_id");

-- 3. "Invoice" → "Customer"
ALTER TABLE "Invoice"
ADD CONSTRAINT fk_invoice_customer
FOREIGN KEY ("customer_id")
REFERENCES "Customer" ("customer_id");

-- 4. "Invoice_line" → "Invoice"
ALTER TABLE "Invoice_line"
ADD CONSTRAINT fk_invoice_line_invoice
FOREIGN KEY ("invoice_id")
REFERENCES "Invoice" ("invoice_id");

-- 5. "Invoice_line" → "Track"
ALTER TABLE "Invoice_line"
ADD CONSTRAINT fk_invoice_line_track
FOREIGN KEY ("track_id")
REFERENCES "track" ("track_id");

-- 6. "Track" → "Album"
ALTER TABLE "track"
ADD CONSTRAINT fk_track_album
FOREIGN KEY ("album_id")
REFERENCES "Album" ("album_id");

-- 7. "Track" → "Media_type"
ALTER TABLE "track"
ADD CONSTRAINT fk_track_media_type
FOREIGN KEY ("media_type_id")
REFERENCES "Media_type" ("media_type_id");

-- 8. "Track" → "Genre"
ALTER TABLE "track"
ADD CONSTRAINT fk_track_genre
FOREIGN KEY ("genre_id")
REFERENCES "Genre" ("genre_id");

-- 9. "Playlist_track" → "Playlist"
ALTER TABLE "playlist_track"
ADD CONSTRAINT fk_playlist_track_playlist
FOREIGN KEY ("playlist_id")
REFERENCES "playlist" ("playlist_id");

-- 10. "Playlist_track" → "Track"
ALTER TABLE "playlist_track"
ADD CONSTRAINT fk_playlist_track_track
FOREIGN KEY ("track_id")
REFERENCES "track" ("track_id");

-- 11. "Employee" → "Employee" (Self-reference for reports_to)
ALTER TABLE "Employee"
ADD CONSTRAINT fk_employee_manager
FOREIGN KEY ("reports_to")
REFERENCES "Employee" ("employee_id");

--BASIC LEVEL

-- most senior employee based on job title

SELECT *
FROM "Employee"
ORDER BY "levels" DESC
LIMIT 1;

-- countries that have the most invoices

SELECT "billing_country", COUNT(*) AS total_invoices
FROM "Invoice"
GROUP BY "billing_country"
ORDER BY total_invoices DESC;

-- top 3 invoice totals

SELECT *
FROM "Invoice"
ORDER BY "total" DESC
LIMIT 3;

-- city with the highest total invoice amount

SELECT "billing_city", SUM("total") AS total_amount
FROM "Invoice"
GROUP BY "billing_city"
ORDER BY total_amount DESC
LIMIT 1;

-- customer who has spent the most money

SELECT c."customer_id", c."first_name", c."last_name", SUM(i."total") AS total_spent
FROM "Customer" c
JOIN "Invoice" i ON c."customer_id" = i."customer_id"
GROUP BY c."customer_id", c."first_name", c."last_name"
ORDER BY total_spent DESC
LIMIT 1;


-- MODERATE LEVEL

--email, first name, and last name of customers who listen to Rock music

SELECT DISTINCT c."email", c."first_name", c."last_name"
FROM "Customer" c
JOIN "Invoice" i ON c."customer_id" = i."customer_id"
JOIN "Invoice_line" il ON i."invoice_id" = il."invoice_id"
JOIN "track" t ON il."track_id" = t."track_id"
JOIN "Genre" g ON t."genre_id" = g."genre_id"
WHERE g."name" = 'Rock';


--top 10 Rock artists based on track count

SELECT ar."name" AS artist_name, COUNT(t."track_id") AS rock_track_count
FROM "Artist" ar
JOIN "Album" al ON ar."artist_id" = al."artist_id"
JOIN "track" t ON al."album_id" = t."album_id"
JOIN "Genre" g ON t."genre_id" = g."genre_id"
WHERE g."name" = 'Rock'
GROUP BY ar."name"
ORDER BY rock_track_count DESC
LIMIT 10;


--track names longer than the average track length

SELECT "name", "milliseconds"
FROM "track"
WHERE "milliseconds" > (
    SELECT AVG("milliseconds") FROM "track"
);


--ADVANCE LEVEL

--how much each customer has spent on each artist

WITH artist_revenue AS (
    SELECT 
        il."invoice_id",
        t."track_id",
        al."artist_id",
        il."unit_price" * il."quantity" AS revenue
    FROM "Invoice_line" il
    JOIN "track" t ON il."track_id" = t."track_id"
    JOIN "Album" a ON t."album_id" = a."album_id"
    JOIN "Artist" al ON a."artist_id" = al."artist_id"
),
customer_artist_spending AS (
    SELECT 
        i."customer_id",
        ar."artist_id",
        SUM(ar."revenue") AS total_spent
    FROM artist_revenue ar
    JOIN "Invoice" i ON ar."invoice_id" = i."invoice_id"
    GROUP BY i."customer_id", ar."artist_id"
)
SELECT 
    c."first_name", 
    c."last_name", 
    a."name" AS artist_name, 
    cas."total_spent"
FROM customer_artist_spending cas
JOIN "Customer" c ON cas."customer_id" = c."customer_id"
JOIN "Artist" a ON cas."artist_id" = a."artist_id"
ORDER BY cas."total_spent" DESC;

--most popular music genre for each country

WITH genre_sales AS (
    SELECT 
        c."country",
        g."name" AS genre_name,
        COUNT(il."invoice_line_id") AS purchase_count
    FROM "Customer" c
    JOIN "Invoice" i ON c."customer_id" = i."customer_id"
    JOIN "Invoice_line" il ON i."invoice_id" = il."invoice_id"
    JOIN "track" t ON il."track_id" = t."track_id"
    JOIN "Genre" g ON t."genre_id" = g."genre_id"
    GROUP BY c."country", g."name"
),
ranked_genres AS (
    SELECT *,
           RANK() OVER (PARTITION BY "country" ORDER BY purchase_count DESC) AS rank
    FROM genre_sales
)
SELECT country, genre_name, purchase_count
FROM ranked_genres
WHERE rank = 1
ORDER BY "country";

--top-spending customer for each country

WITH customer_spending AS (
    SELECT 
        c."customer_id",
        c."first_name",
        c."last_name",
        c."country",
        SUM(i."total") AS total_spent
    FROM "Customer" c
    JOIN "Invoice" i ON c."customer_id" = i."customer_id"
    GROUP BY c."customer_id", c."first_name", c."last_name", c."country"
),
ranked_customers AS (
    SELECT *,
           RANK() OVER (PARTITION BY country ORDER BY total_spent DESC) AS rank
    FROM customer_spending
)
SELECT country, first_name, last_name, total_spent
FROM ranked_customers
WHERE rank = 1
ORDER BY "country";





