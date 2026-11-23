// OPTIONAL / UNGRADED. Complete after required parts are working.
// Create a weighted movie-movie graph from shared high ratings.
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0 AND m1.movieId < m2.movieId
WITH m1, m2, count(DISTINCT u) AS weight
WHERE weight >= 2
ORDER BY weight DESC LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Projection and PageRank: check GDS procedures first, then uncomment/run.
// CALL gds.graph.project('movieGraph', 'Movie',
//   {CO_RATED: {orientation: 'UNDIRECTED', properties: 'weight'}})
// YIELD graphName, nodeCount, relationshipCount;
// TODO: gds.pageRank.stream('movieGraph', {relationshipWeightProperty: 'weight'})
// TODO: create User-SIMILAR-User graph and run Louvain.
// TODO: run Dijkstra on the user similarity graph.
// Cleanup after algorithms:
// CALL gds.graph.drop('movieGraph') YIELD graphName;
// MATCH ()-[r:CO_RATED]-() DELETE r;
