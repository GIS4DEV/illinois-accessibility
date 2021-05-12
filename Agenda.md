# Future tasks for this project
- translate the data gathering/pre-processing tasks developed by Kufre in R into the Python notebook
- a big stumbling block was python for creating a hexagonal tesselation.
  - This might be the answer: https://github.com/urschrei/hexcover
  - or this might be: https://duspviz.org/tutorials/modules/14/ 
  - remember to create an 'area' field, or perhaps better yet, don't store that and consider it a constant in future versions of the notebook
  - actually, is it necessary to compare areas at all? after all, what convex hull polygon would not intersect the center of a hexagon before it covered 50% of its area?
- add code for creating all the maps and graphs in the published paper
- thoroughly benchmark differences in processing times
- look for opportunities to maintain data as attributes/tables without geometries only, including a data structure representing relationships between hospitals, tracts, zip code tabulation areas, and hexagons
