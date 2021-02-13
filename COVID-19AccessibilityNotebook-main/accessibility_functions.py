import pandas as pd
import numpy as np
import geopandas as gpd
import networkx as nx
import osmnx as ox
from shapely.geometry import Point, LineString, Polygon
import matplotlib.pyplot as plt
from tqdm import tqdm
import multiprocessing as mp
import folium, itertools, os, time, warnings

def create_catchment_area(g):
    nodes = [Point((data['x'], data['y'])) for node, data in g.nodes(data=True)]
    polygon = gpd.GeoSeries(nodes).unary_union.convex_hull ## to create convex hull
    polygon = gpd.GeoDataFrame(gpd.GeoSeries(polygon)) ## change polygon to geopandas
    polygon = polygon.rename(columns={0:'geometry'}).set_geometry('geometry')
    return polygon.copy(deep=True)

def hospital_measure_acc (_thread_id, hospital, pop_data, distances, weights,network, distance_unit = 'time'):
    ##distance weight = 1, 0.68, 0.22
    polygons = []

    sorted_dist = sorted(distances, reverse = True)

    g_dict = nx.single_source_dijkstra_path_length(network, hospital['nearest_osm'], sorted_dist[0], distance_unit)
    g = network.subgraph(g_dict)

    for distance in sorted_dist:
        if distance == max(distances):
            polygons.append(create_catchment_area(g))
        else:
            g_dict = {key: value for (key, value) in g_dict.items() if value <= distance}
            g = g.subgraph(g_dict)
            polygons.append(create_catchment_area(g))

    polygons.reverse()

    for i in range(1, len(distances)):
        polygons[i] = gpd.overlay(polygons[i], polygons[i-1], how="difference")

    num_pops = []
    for j in pop_data.index:
        point = pop_data['geometry'][j]
        for k in range(len(polygons)):
            if len(polygons[i]) > 0: # to exclude the weirdo (convex hull is not polygon)
                if (point.within(polygons[k].iloc[0]["geometry"])):
                    num_pops.append(pop_data['pop'][j]*weights[k])
    total_pop = sum(num_pops)
    for i in range(len(distances)):
        polygons[i]['time']=distances[i]
        polygons[i]['total_pop']=total_pop
        polygons[i]['hospital_icu_beds'] = float(hospital['Adult ICU'])/polygons[i]['total_pop'] # proportion of # of beds over pops in 10 mins
        polygons[i]['hospital_vents'] = float(hospital['Total Vent'])/polygons[i]['total_pop'] # proportion of # of beds over pops in 10 mins
        polygons[i].crs = { 'init' : 'epsg:4326'}
        polygons[i] = polygons[i].to_crs({'init':'epsg:32616'})
    print('\rCatchment for hospital {:4.0f} complete'.format(_thread_id), end="")
    return(_thread_id, [ polygon.copy(deep=True) for polygon in polygons ])

def hospital_acc_unpacker(args):
    return hospital_measure_acc(*args)

from collections import Counter
def overlap_calc(_id, poly, grid_file, weight, service_type):
    value_dict = Counter()
    if type(poly.iloc[0][service_type])!=type(None):
        value = float(poly[service_type])*weight
        intersect = gpd.overlay(grid_file, poly, how='intersection')
        intersect['overlapped']= intersect.area
        intersect['percent'] = intersect['overlapped']/intersect['area']
        intersect=intersect[intersect['percent']>=0.5]
        intersect_region = intersect['id']
        for intersect_id in intersect_region:
            try:
                value_dict[intersect_id] +=value
            except:
                value_dict[intersect_id] = value
    return(_id, value_dict)

def overlap_calc_unpacker(args):
    return overlap_calc(*args)
