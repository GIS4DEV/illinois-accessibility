# collecting data  --------------------------------------------------------
library(sf)
library(here)
library(reticulate)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

dt = 'data'
if(!dir.exists(dt)) dir.create(here(dt))

if (!('geo' %in% conda_list()$name)) {
  conda_create('geo', forge = T)
  conda_install('geo', packages = 'osmnx',forge = T)
}

use_condaenv('geo')

ox = import('osmnx')

if (!file.exists(here(dt,'il_network.graphml'))) {
  network = ox$graph_from_place('Illinois',
                                buffer_dist = 15000,
                                network_type = 'drive')
  ox$save_graphml(network, here(dt,'il_network.graphml'))
}

utm = 32616

tracts = get_acs(
  year = 2019,
  variables = c(total, vars),
  geography = 'tract',
  state = 'il',
  geometry = T,
  output = 'wide'
) %>%
  select(contains('E')) %>%
  rename(total = 'B01001_001E') %>%
  rowwise %>%
  mutate(above_50 = sum(c_across(paste0(vars, 'E'))),
         state = "il") %>%
  select(!contains(vars)) %>% 
  st_transform(utm) 

il = group_by(tracts,state) %>% summarize

hospital = read_sf(
  'https://opendata.arcgis.com/datasets/6ac5e325468c4cb9b905f1728d6fbf0f_0.geojson'
) %>%
  st_transform(utm) %>%
  filter(lengths(st_intersects(., st_buffer(il, 15000))) > 0  &
           TYPE == 'GENERAL ACUTE CARE')

icu = read_csv(
  'https://healthdata.gov/sites/default/files/reported_hospital_capacity_admissions_facility_level_weekly_average_timeseries_20210117.csv'
) %>%
  select(1:13, total_icu_beds_7_day_avg) %>%
  mutate(address = str_to_upper(address)) %>%
  rename_with( ~ paste0(.x, '_icu'))

hospital_icu = left_join(hospital, icu, by = c('ADDRESS' = 'address_icu'))

vars = paste0('B01001_0', c(16:25, 40:49))
total = 'B01001_001'

hex_il = st_make_grid(
  il,
  cellsize = c(1500, 1500),
  square = F,
  flat_topped = T
) %>%
  .[lengths(st_intersects(., il)) > 0]

gpkg = here(dt,'il_data.gpkg')
write_sf(hex_il, gpkg , 'hex_grid')
write_sf(tracts, gpkg, 'tracts')
write_sf(hospital_icu, gpkg, 'hospital_icu')