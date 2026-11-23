# NoSQL --- Homework 3: Neo4j and MovieLens 1M

**Author:** Sakhno\
**Database:** Neo4j 5.18.1 Community\
**Environment:** Docker Desktop + WSL2\
**Dataset:** MovieLens 1M

> Document status: Parts 1--3 are documented based on completed work.
> Parts 4 and 6 are pending completion. Part 5 is optional and has not
> been reported as completed.

------------------------------------------------------------------------

## 1. Running the Project

### Requirements

-   Docker Desktop with the WSL2 backend.
-   Docker Compose.
-   Neo4j 5.18 Community.
-   Python 3 for dataset conversion.

Start Neo4j from the project root:

``` powershell
docker compose up -d
docker compose ps
```

Neo4j Browser: http://localhost:7474\
Bolt: `bolt://localhost:7687`

Check the Neo4j version:

``` cypher
CALL dbms.components()
YIELD name, versions, edition
RETURN name, versions, edition;
```

The environment was verified with Neo4j Kernel `5.18.1`, edition
`community`, and APOC `5.18.0`.

## 2. Project Structure

``` text
Sakhno_nosql_3/
├── import/
│   ├── movies.csv
│   ├── ratings.csv
│   └── users.csv
├── ml-1m/
│   ├── movies.dat
│   ├── ratings.dat
│   ├── users.dat
│   └── README
├── queries/
│   ├── part3.cypher
│   ├── part4_supernodes.cypher
│   └── part5_gds.cypher
├── scripts/
│   └── convert_movielens.py
├── docker-compose.yml
├── part2_load.cypher
├── requirements.txt
└── README.md
```

## 3. Part 1 --- Graph Schema Design

### 3.1. Graph Model

The project uses three node labels and two relationship types:

``` text
(:User {
    userId,
    gender,
    age,
    occupation
})

(:Movie {
    movieId,
    title,
    year
})

(:Genre {
    name
})

(:User)-[:RATED {
    rating,
    timestamp
}]->(:Movie)

(:Movie)-[:HAS_GENRE]->(:Genre)
```

ASCII diagram:

``` text
(:User) ──[:RATED {rating, timestamp}]──> (:Movie)
                                               |
                                         [:HAS_GENRE]
                                               |
                                               v
                                           (:Genre)
```

### 3.2. Which Entities Are Nodes and Which Are Relationships?

`User`, `Movie`, and `Genre` are independent domain entities, so they
are represented as nodes. Each has its own identifier or key properties
and can be referenced by other parts of the graph.

`RATED` and `HAS_GENRE` are represented as relationships. `RATED`
describes a user's rating of a movie, while `HAS_GENRE` describes a
movie's membership in a genre. Relationships make it possible to
traverse the graph directly through domain relationships.

### 3.3. Why Is a Rating a Relationship Rather Than a Separate Rating Node?

In this model, a rating belongs to a specific user--movie pair, so it is
stored as a relationship with properties:

``` text
(:User)-[:RATED {rating, timestamp}]->(:Movie)
```

This approach is more compact and allows direct traversal from a user to
the movies they rated. It also matches the MovieLens data structure,
where each rating record contains a user, a movie, a rating value, and a
timestamp.

An alternative is to model each rating as a separate `(:Rating)` node
connected to both `User` and `Movie`. This is useful if a rating becomes
an independent entity---for example, if moderation data, edit history,
comments, or source information must be attached to it. The trade-off is
additional nodes and relationships, as well as more complex queries for
ordinary rating retrieval.

For the current dataset, the `RATED` relationship is the simpler and
more suitable model.

### 3.4. Why Are Genres Separate Nodes?

Separate `Genre` nodes allow one genre to be connected to many movies,
support graph traversal, and make it straightforward to aggregate
ratings by genre. Each genre is stored once rather than repeated as a
string value on every movie.

If genres were stored only as an array property on `Movie`, queries by
genre and traversals between movies in the same genre would be less
natural for a graph model. Separate nodes make the relationship
explicit:

``` text
(:Movie)-[:HAS_GENRE]->(:Genre)
```

------------------------------------------------------------------------

## 4. Part 2 --- Loading MovieLens 1M

### 4.1. Data Preparation

The original MovieLens files use the `::` delimiter and Latin-1
encoding. The `scripts/convert_movielens.py` script converts the `.dat`
files into UTF-8 CSV files with headers.

The source files are stored in `ml-1m/`, and the converted files are
written to `import/`.

Run the script from the project root:

``` powershell
python .\scripts\convert_movielens.py
```

Conversion results:

  File              Number of records
  --------------- -------------------
  `movies.csv`                  3,883
  `ratings.csv`             1,000,209
  `users.csv`                   6,040

The script validates the expected number of fields in each source row
and raises an error if a row has an invalid format.

### 4.2. Importing Data into Neo4j

The import is performed by the queries in `part2_load.cypher`:

1.  `User` nodes are created using `MERGE`.
2.  `Movie` nodes are created; the release year is extracted from the
    title when it ends with `(YYYY)`.
3.  `Genre` nodes and `HAS_GENRE` relationships are created.
4.  Indexes are created for `User.userId`, `Movie.movieId`, and
    `Genre.name`.
5.  Ratings are imported in batches using `apoc.periodic.iterate`, with
    `batchSize: 10000` and `parallel: false`.

`MERGE` is used to avoid creating duplicate nodes and relationships if
the import is executed again. The indexes help Neo4j find users and
movies more efficiently when creating `RATED` relationships.

`parallel: false` was selected to process batches sequentially and
reduce the risk of write conflicts while using `MERGE`.

### 4.3. Verified Import Results

Validation queries:

``` cypher
MATCH (u:User) RETURN count(u) AS users;
MATCH (m:Movie) RETURN count(m) AS movies;
MATCH (g:Genre) RETURN count(g) AS genres;
MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;
```

Actual results:

  Entity / relationship         Count
  ----------------------- -----------
  `User`                        6,040
  `Movie`                       3,883
  `Genre`                          18
  `RATED`                   1,000,209

All four validation counts matched the expected values for the dataset
used.

------------------------------------------------------------------------

## 5. Part 3 --- Cypher Queries of Different Complexity

All six queries were executed in Neo4j Browser against the imported
MovieLens 1M dataset.

### Query 1. Thriller Movies with an Average Rating Above 4.0

``` cypher
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre {name: 'Thriller'})
MATCH (:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS avgRating, count(r) AS ratingsCount
WHERE avgRating > 4.0
RETURN
    m.movieId AS movieId,
    m.title AS title,
    round(avgRating, 2) AS averageRating,
    ratingsCount
ORDER BY averageRating DESC, ratingsCount DESC;
```

**Explanation.** The query first finds movies connected to the
`Thriller` genre and then collects all ratings for each movie. `avg()`
calculates the average rating, while `count()` calculates the number of
ratings. After aggregation, `WHERE avgRating > 4.0` filters the results.

**Result:** 52 movies were found. For example,
`The Usual Suspects (1995)` has an average rating of 4.52 based on 1,783
ratings.

### Query 2. Users Who Gave a Rating of 5 to More Than 50 Movies

``` cypher
MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5
WITH u, count(r) AS fiveStarRatings
WHERE fiveStarRatings > 50
RETURN
    u.userId AS userId,
    u.gender AS gender,
    u.age AS age,
    fiveStarRatings
ORDER BY fiveStarRatings DESC;
```

**Explanation.** The query selects `RATED` relationships with
`rating = 5`, groups them by user, and counts the number of five-star
ratings. The second filter keeps users with more than 50 such ratings.

**Result:** 1,390 users were found. The highest count visible in the
result was 571 five-star ratings for user `userId = 4277`.

### Query 3. Movies Highly Rated by Both Users

``` cypher
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
MATCH (u2:User {userId: 2})-[r2:RATED]->(m)
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN
    m.movieId AS movieId,
    m.title AS title,
    r1.rating AS user1Rating,
    r2.rating AS user2Rating
ORDER BY m.title;
```

**Explanation.** The query matches two paths from users `1` and `2` to
the same `Movie` node. Both relationship conditions require a rating of
at least 4. Matching the same node `m` ensures that only movies rated
highly by both users are returned.

**Result:** 6 movies were found. One example is
`One Flew Over the Cuckoo's Nest (1975)`, which both users rated 5.

### Query 4. Average Rating and Number of Ratings by Genre

``` cypher
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
MATCH (:User)-[r:RATED]->(m)
WITH
    g,
    avg(r.rating) AS avgRating,
    count(r) AS ratingsCount
RETURN
    g.name AS genre,
    round(avgRating, 2) AS averageRating,
    ratingsCount
ORDER BY averageRating DESC;
```

**Explanation.** The query traverses from genres to movies and then to
the ratings of those movies. It calculates the average rating and total
number of ratings for each genre. A movie can belong to multiple genres,
so its ratings contribute to the aggregation for each of its genres.

**Result:** Aggregates were returned for all 18 genres. `Film-Noir`
ranked first with an average rating of 4.08 and 18,261 ratings. `Drama`
had an average rating of 3.77 across 354,529 ratings.

### Query 5. Recommendations Based on Similar Preferences

``` cypher
MATCH (target:User {userId: 1})-[targetRating:RATED]->(common:Movie)
WHERE targetRating.rating >= 4

MATCH (similar:User)-[similarRating:RATED]->(common)
WHERE similar.userId <> target.userId
  AND similarRating.rating >= 4

MATCH (similar)-[recommendation:RATED]->(recommended:Movie)
WHERE recommendation.rating >= 4
  AND NOT EXISTS {
      MATCH (target)-[:RATED]->(recommended)
  }

WITH
    recommended,
    count(DISTINCT similar) AS recommendingUsers,
    avg(recommendation.rating) AS averageRating

RETURN
    recommended.movieId AS movieId,
    recommended.title AS title,
    recommendingUsers,
    round(averageRating, 2) AS averageRating
ORDER BY recommendingUsers DESC, averageRating DESC
LIMIT 20;
```

**Explanation.** First, the query finds movies rated 4 or 5 by the
target user (`userId = 1`). It then finds other users who also rated
those shared movies highly. Finally, it selects movies rated 4 or 5 by
those users but not yet rated by the target user.

`count(DISTINCT similar)` shows how many distinct users support a
recommendation. The result is limited to 20 movies.

This is a basic collaborative-filtering approach based on overlapping
highly rated movies. It does not calculate a formal correlation or
user-similarity coefficient.

**Result:** 20 recommendations were returned. The first was
`American Beauty (1999)`, supported by 2,770 recommending users, with an
average rating of 4.70. The query took approximately 25.6 seconds.

### Query 6. Shortest Path Between Two Users

``` cypher
MATCH (u1:User {userId: 1}),
      (u2:User {userId: 2})
MATCH p = shortestPath((u1)-[:RATED*..6]-(u2))
RETURN
    [n IN nodes(p) |
        CASE
            WHEN n:User THEN 'User ' + toString(n.userId)
            WHEN n:Movie THEN n.title
        END
    ] AS connectionPath,
    length(p) AS pathLength;
```

**Explanation.** The query searches for the shortest path between users
`1` and `2` by traversing `RATED` relationships in either direction. The
`*..6` constraint limits the maximum path length to six relationships.
`nodes(p)` returns the nodes on the path, and `length(p)` returns the
number of relationships traversed.

**Actual result:**

``` text
User 1 → Awakenings (1990) → User 2
```

The path length is 2.

### 5.1. How Should Path Length Be Interpreted?

Path length is the number of relationships traversed in the graph. In
this model, each `RATED` relationship connects a user to a movie.

-   **Length 2:** two users rated the same movie. The path consists of
    two relationships: `User → Movie → User`.
-   **Length 4:** the users are connected through one intermediate user
    and two movies: `User A → Movie 1 → User B → Movie 2 → User C`.
-   **Length 6:** two intermediate users and three movies lie between
    the endpoints:
    `User A → Movie 1 → User B → Movie 2 → User C → Movie 3 → User D`.

Therefore, path length represents the number of `RATED` relationships
needed to connect users through shared movies.

### 5.2. Part 3 Summary

    \# Query                                       Actual result
  ---- ------------------------------------------- -----------------
     1 Thrillers with average rating above 4.0     52 movies
     2 Users with more than 50 five-star ratings   1,390 users
     3 Movies rated at least 4 by users 1 and 2    6 movies
     4 Rating aggregation by genre                 18 genres
     5 Recommendations for user 1                  20 movies
     6 Shortest path between users 1 and 2         2 relationships

------------------------------------------------------------------------

## 6. Part 4 --- Identifying Supernodes

**Status: pending execution and recording of actual results.**

This part requires identifying nodes with unusually high degrees,
recording their degrees, and explaining how such nodes can affect query
performance.

After executing the queries in `queries/part4_supernodes.cypher`, add:

-   the labels and identifiers of the supernodes found;
-   the number of relationships for each node;
-   a performance comparison between queries involving high-degree and
    ordinary nodes;
-   the selected strategy for handling supernodes, including genres.

Actual results are not included yet, to avoid presenting assumptions as
measured findings.

------------------------------------------------------------------------

## 7. Part 5 --- Graph Data Science (Optional)

**Status: optional part; execution and results have not been recorded.**

The assignment proposes three areas:

1.  PageRank on a graph of movies connected through users who rated both
    movies highly.
2.  Louvain for detecting communities of users with similar preferences.
3.  Dijkstra for finding a weighted shortest path between users.

If this optional part is completed, document the queries and actual
results in `queries/part5_gds.cypher` and in this section.

------------------------------------------------------------------------

## 8. Part 6 --- Analysis and Conclusions

**Status: pending completion.**

### 8.1. Graph Model vs. SQL

After completing the analysis, compare selected Part 3 queries with
their SQL equivalents. Pay particular attention to the recommendation
query and shortest-path search: in a relational model, these operations
require explicit JOINs, recursive queries, or additional intermediate
computations.

### 8.2. Where Does the Graph Model Have Disadvantages Compared with a Relational Model?

Add an analysis of tasks for which a relational model may be more
convenient, such as large tabular aggregations, reporting, exports, and
processing data with a fixed structure.

### 8.3. Possible Schema Improvements

Consider at least two specific Part 3 queries and propose schema or
indexing changes that could improve their performance. Explain the
expected effect.

------------------------------------------------------------------------

## 9. Result Screenshots

The assignment requires screenshots of the Neo4j Browser results for
Part 3 (the first 10 rows are sufficient).

Suggested filenames:

``` text
screenshots/
├── part3_query1_thriller.png
├── part3_query2_top_raters.png
├── part3_query3_common_movies.png
├── part3_query4_genre_ratings.png
├── part3_query5_recommendations.png
└── part3_query6_shortest_path.png
```

Screenshots can be embedded in this README using Markdown:

``` markdown
![Part 3 — Query 1](screenshots/part3_query1_thriller.png)
```

------------------------------------------------------------------------

## 10. Final Submission Checklist

-   [x] Neo4j started using Docker Compose.
-   [x] MovieLens 1M converted to CSV.
-   [x] 6,040 users imported.
-   [x] 3,883 movies imported.
-   [x] 18 genres created.
-   [x] 1,000,209 `RATED` relationships imported.
-   [x] All 6 Part 3 queries executed.
-   [ ] Part 3 result screenshots added to the repository.
-   [ ] Part 4 completed: supernodes and optimization strategy.
-   [ ] Part 6 completed: comparison of graph and relational models.
-   [ ] All project files and README reviewed before creating the
    submission archive.

**Note:** Part 5 graph algorithms are optional according to the
assignment description.
