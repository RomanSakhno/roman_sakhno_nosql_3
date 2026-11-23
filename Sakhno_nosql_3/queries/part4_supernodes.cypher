// 1. Nodes with the highest total degree.
MATCH (n)-[r]-()
WITH n, count(r) AS degree
RETURN labels(n) AS labels,
       CASE WHEN n:User THEN toString(n.userId)
            WHEN n:Movie THEN toString(n.movieId)
            WHEN n:Genre THEN n.name ELSE elementId(n) END AS nodeKey,
       degree
ORDER BY degree DESC LIMIT 30;

// 2. Genre nodes: count connected movies.
MATCH (g:Genre)<-[r:HAS_GENRE]-(:Movie)
WITH g, count(r) AS movieConnections
RETURN g.name AS genre, movieConnections
ORDER BY movieConnections DESC;

// 3. Degree distribution by node label.
MATCH (n)-[r]-()
WITH n, count(r) AS degree
UNWIND labels(n) AS label
RETURN label, count(*) AS nodes,
       round(avg(degree), 2) AS averageDegree, max(degree) AS maximumDegree
ORDER BY maximumDegree DESC;
