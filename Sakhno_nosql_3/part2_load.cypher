// Run after converting the MovieLens files into import/*.csv.

// 1. Users
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender = row.gender, u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// 2. Movies and release year (when title ends in (YYYY)).
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.year = CASE WHEN row.title =~ '.*\\([0-9]{4}\\)$'
      THEN toInteger(substring(row.title, size(row.title) - 5, 4)) ELSE null END;

// 3. Genres as nodes.
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MATCH (m:Movie {movieId: toInteger(row.movieId)})
UNWIND split(row.genres, '|') AS genreName
WITH m, trim(genreName) AS genreName
WHERE genreName <> '' AND genreName <> '(no genres listed)'
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);

// 4. Indexes before loading RATED relationships.
CREATE INDEX user_userId IF NOT EXISTS FOR (u:User) ON (u.userId);
CREATE INDEX movie_movieId IF NOT EXISTS FOR (m:Movie) ON (m.movieId);
CREATE INDEX genre_name IF NOT EXISTS FOR (g:Genre) ON (g.name);

// 5. Ratings in batches; keep parallel:false while using MERGE.
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User {userId: toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET r.rating = toFloat(row.rating), r.timestamp = toInteger(row.timestamp)",
  {batchSize: 10000, parallel: false}
)
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;

// 6. Validation counts
MATCH (u:User) RETURN count(u) AS users;
MATCH (m:Movie) RETURN count(m) AS movies;
MATCH (g:Genre) RETURN count(g) AS genres;
MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;
