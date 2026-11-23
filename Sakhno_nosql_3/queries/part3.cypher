// 1. Thriller movies with average rating > 4.0.
MATCH (m:Movie)-[:HAS_GENRE]->(:Genre {name: 'Thriller'})
MATCH (:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS averageRating, count(r) AS ratingCount
WHERE averageRating > 4.0
RETURN m.movieId AS movieId, m.title AS title,
       round(averageRating, 3) AS averageRating, ratingCount
ORDER BY averageRating DESC, ratingCount DESC;

// 2. Users who gave 5 stars to more than 50 movies.
MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5.0
WITH u, count(r) AS fiveStarCount
WHERE fiveStarCount > 50
RETURN u.userId AS userId, u.gender AS gender, fiveStarCount
ORDER BY fiveStarCount DESC;

// 3. Movies both user 1 and user 2 rated >= 4.
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
MATCH (u2:User {userId: 2})-[r2:RATED]->(m)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0
RETURN m.movieId AS movieId, m.title AS title,
       r1.rating AS user1Rating, r2.rating AS user2Rating
ORDER BY title;

// 4. Genre average rating and number of ratings.
MATCH (:User)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WITH g, avg(r.rating) AS averageRating, count(r) AS ratingCount
RETURN g.name AS genre, round(averageRating, 3) AS averageRating, ratingCount
ORDER BY averageRating DESC, ratingCount DESC;

// 5. Recommend unseen movies based on users with overlapping high ratings.
MATCH (target:User {userId: 1})-[mine:RATED]->(shared:Movie)<-[theirs:RATED]-(similar:User)
WHERE mine.rating >= 4.0 AND theirs.rating >= 4.0 AND similar <> target
WITH target, similar, count(DISTINCT shared) AS overlap
WHERE overlap >= 3
MATCH (similar)-[rec:RATED]->(candidate:Movie)
WHERE rec.rating >= 4.0
  AND NOT EXISTS { MATCH (target)-[:RATED]->(candidate) }
WITH candidate, count(DISTINCT similar) AS recommendingUsers,
     avg(rec.rating) AS averageRating
RETURN candidate.movieId AS movieId, candidate.title AS title,
       recommendingUsers, round(averageRating, 3) AS averageRating
ORDER BY recommendingUsers DESC, averageRating DESC
LIMIT 20;

// 6. Shortest user-to-user path through rated movies, up to 6 RATED hops.
MATCH p = shortestPath((u1:User {userId: 1})-[:RATED*..6]-(u2:User {userId: 2}))
RETURN p, length(p) AS relationshipHops, length(p) / 2 AS sharedMovieSteps;
