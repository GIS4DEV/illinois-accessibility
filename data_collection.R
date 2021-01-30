# collecting data  --------------------------------------------------------
library(sf)
library(here)
library(reticulate)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

dt = 'data'

# change if necessary 
crs = 32616 
net_file = here(dt,'il_network.graphml')
gpkg = here(dt,'il_data.gpkg')  
state_abbrv = 'IL'
state_name = 'Illinois'
covid_csv = 'https://idph.illinois.gov/DPHPublicInformation/api/COVIDExport/GetZip?format=csv'
covid_fp = here(dt,'il_zip_covid.csv') 

read_csv(
  covid_csv, 
  skip = 1 # first line may not need to be skipped, check if necessary
) %>% 
  write_csv(covid_fp)

if(!dir.exists(dt)) dir.create(here(dt))

if (!('geo' %in% conda_list()$name)) {
  conda_create('geo', forge = T)
  conda_install('geo', packages = 'osmnx',forge = T)
}

if (!file.exists(net_file)) {
  use_condaenv('geo')
  
  ox = import('osmnx')
  
  network = ox$graph_from_place(state_name, network_type = 'drive')
  ox$save_graphml(network, net_file)
}

vars = paste0('B01001_0', c(16:25, 40:49))
total = 'B01001_001'

tracts = get_acs(
  year = 2019,
  variables = c(total, vars),
  geography = 'tract',
  state = state_abbrv,
  geometry = T,
  output = 'wide'
) %>%
  select(contains('E')) %>%
  rename(total = 'B01001_001E') %>%
  rowwise %>%
  mutate(above_50 = sum(c_across(paste0(vars, 'E')))) %>%
  select(!contains(vars)) %>% 
  st_transform(crs) 

state = mutate(tracts, state = state_abbrv) %>%
  group_by(state) %>%
  summarize

hospital = read_sf(
  'https://opendata.arcgis.com/datasets/6ac5e325468c4cb9b905f1728d6fbf0f_0.geojson'
) %>%
  st_transform(crs) %>%
  filter(lengths(st_intersects(., state)) > 0  &
           TYPE == 'GENERAL ACUTE CARE')

icu = read_sf(
  'https://opendata.arcgis.com/datasets/6ac5e325468c4cb9b905f1728d6fbf0f_0.geojson'
) %>%
  st_drop_geometry() %>% 
  select(1:13, total_icu_beds_7_day_avg) %>%
  mutate(address = str_to_upper(address)) %>%
  rename_with( ~ paste0(.x, '_icu'))

hospital_icu = left_join(hospital, icu, by = c('ADDRESS' = 'address_icu'))

hex = st_make_grid(
  state,
  cellsize = c(1500, 1500),
  square = F,
  flat_topped = T
) %>%
  .[lengths(st_intersects(., state)) > 0]

write_sf(hex, gpkg , 'hex_grid')
write_sf(tracts, gpkg, 'tracts')
write_sf(hospital_icu, gpkg, 'hospital_icu')