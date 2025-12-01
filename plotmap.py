# -*- coding: utf-8 -*-
"""
Created on Mon Apr 25 14:08:50 2022
Edited 4 Dec 2023 for PANGU

@author: pas

Plotting z500/mlsp
"""

import eccodes
import numpy as np
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from matplotlib.patches import Path, PathPatch
import argparse
from datetime import datetime, timedelta


# setting some of the color maps of MetDesk 
#https://matplotlib.org/stable/tutorials/colors/colormap-manipulation.html
MetDesk_wind_cols = [
     [0.99608, 0.99608, 0.99608, 1.0], 
     [0.80000, 0.99608, 0.99608, 1.0], 
     [0.66275, 0.98039, 0.99608, 1.0], 
     [0.56471, 0.88627, 1.00000, 1.0], 
     [0.45098, 0.76078, 0.99608, 1.0], 
     [0.34510, 0.54902, 0.99608, 1.0], 
     [0.21961, 0.29804, 0.99608, 1.0], 
     [0.05098, 0.47059, 0.13725, 1.0], 
     [0.34510, 0.67451, 0.25490, 1.0], 
     [0.41961, 0.81569, 0.30980, 1.0], 
     [0.63529, 0.89804, 0.70980, 1.0], 
     [0.99608, 0.99608, 0.49412, 1.0], 
     [1.00000, 0.90980, 0.38431, 1.0], 
     [0.99608, 0.79608, 0.28627, 1.0], 
     [1.00000, 0.74510, 0.14902, 1.0], 
     [1.00000, 0.59608, 0.24314, 1.0], 
     [1.00000, 0.34510, 0.18039, 1.0], 
     [1.00000, 0.20000, 0.09412, 1.0], 
     [1.00000, 0.00784, 0.00784, 1.0], 
     [0.67843, 0.00000, 0.00000, 1.0], 
     [0.65882, 0.02745, 0.67843, 1.0],   
     [0.67843, 0.28235, 0.67059, 1.0], 
     [0.87059, 0.36078, 0.86275, 1.0], 
     [0.98039, 0.59608, 0.94510, 1.0], 
     [0.98039, 0.77647, 0.96078, 1.0], 
     [0.89412, 0.89412, 0.89412, 1.0], 
     [0.82745, 0.82745, 0.82745, 1.0], 
     [0.72941, 0.72941, 0.72941, 1.0]]
MetDesk_wind_ticks = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,30,35]
wind10m_map = ListedColormap(MetDesk_wind_cols)
      
MetDesk_z500_cols = [    
      [0.565, 0, 0.573, 1.0], 
      [0.784, 0, 0.784, 1.0], 
      [0.976, 0, 0.992, 1.0], 
      [0.784, 0, 0.992, 1.0], 
      [0.584, 0, 0.992, 1.0], 
      [0.392, 0, 0.992, 1.0], 
      [0.192, 0, 0.992, 1.0], 
      [0, 0.192, 0.992, 1.0], 
      [0, 0.392, 0.992, 1.0], 
      [0, 0.584, 0.992, 1.0], 
      [0, 0.784, 0.992, 1.0], 
      [0, 0.898, 0.937, 1.0], 
      [0, 0.898, 0.627, 1.0], 
      [0, 0.898, 0.467, 1.0], 
      [0, 0.898, 0.31, 1.0], 
      [0, 0.937, 0.153, 1.0], 
      [0, 0.976, 0, 1.0], 
      [0.439, 0.976, 0, 1.0], 
      [0.992, 0.933, 0, 1.0], 
      [0.992, 0.933, 0, 1.0], 
      [0.988, 0.784, 0, 1.0], 
      [0.988, 0.686, 0, 1.0], 
      [0.988, 0.584, 0, 1.0], 
      [0.902, 0.431, 0, 1.0], 
      [0.902, 0.431, 0, 1.0], 
      [0.859, 0.294, 0.114, 1.0], 
      [0.78, 0.192, 0.114, 1.0], 
      [0.702, 0.094, 0.114, 1.0], 
      [0.698, 0.024, 0.18, 1.0], 
      [0.698, 0.024, 0.18, 1.0], 
      [0.796, 0, 0.408, 1.0]]
z500_cmap = ListedColormap(MetDesk_z500_cols)


MetDesk_winddiff_cols = [
    [0.2275, 0, 0.3451,  1.0],
    [0.4078, 0, 0.6118,  1.0],
    [0.6667, 0.0118, 0.9961,  1.0],
    [0.6314, 0.1882, 0.9961,  1.0],
    [0.8471, 0.5373, 1,  1.0],
    [0.9059, 0.7373, 1,  1.0],
    [0.9725, 0.8784, 1,  1.0],
    [0.9961, 0.9961, 0.9961,  1.0],
    [0.9961, 0.9961, 0.9961,  1.0],
    [0.9961, 0.9961, 0.7922,  1.0],
    [0.9961, 0.9961, 0.5961,  1.0],
    [1.0000, 0.8, 0,  1.0],
    [0.9961, 0.5961, 0,  1.0],
    [0.9961, 0.251, 0.2,  1.0],
    [0.7961, 0, 0.3961,  1.0],
    [0.5098, 0, 0.2549,  1.0],
    [0.2980, 0, 0.149,  1.0]]
winddiff_levs = [-25, -12, -10, -8, -6, -4, -2, -1, 0, 1, 2, 4, 6, 8, 10, 12, 25]
tempdiff_levs = [-25, -12, -10, -8, -6, -4, -2, -1, 0, 1, 2, 4, 6, 8, 10, 12, 25]

MetDesk_gphdiff_cols = [
    [0.247, 0, 0.345, 1.0],
    [0.329, 0, 0.459, 1.0],
    [0.529, 0, 0.741, 1.0],
    [0.71, 0, 0.988, 1.0],
    [0.847, 0.133, 0.988, 1.0],
    [0.8, 0.318, 0.988, 1.0],
    [0, 0, 0.729, 1.0],
    [0, 0, 1, 1.0],
    [0.224, 0.561, 1, 1.0],
    [0, 0.8, 1, 1.0],
    [0.439, 1, 1, 1.0],
    [1, 1, 1, 1.0],
    [1, 1, 0.498, 1.0],
    [1, 1, 0, 1.0],
    [1, 0.957, 0.439, 1.0],
    [1, 0.788, 0.294, 1.0],
    [0.918, 0.725, 0.271, 1.0],
    [1, 0.667, 0, 1.0],
    [1, 0.4, 0, 1.0],
    [1, 0.22, 0.067, 1.0],
    [0.792, 0.235, 0.133, 1.0],
    [0.655, 0.192, 0.11, 1.0],
    [0.514, 0.149, 0.086, 1.0],
    [0.404, 0, 0, 1.0]]
gphdiff_levs = [-100, -40, -35, -30, -25, -20, -15, -10, -8, -6, -4, -2, 2, 4, 6, 8, 10, 15, 20, 25, 30, 35, 40, 100]

MetDesk_temp_cols = [
    [0.9255, 0.9529, 0.9529, 1.0],
    [0.9255, 0.9529, 0.9529, 1.0],
    [0.8196, 0.8196, 0.8196, 1.0],
    [0.6275, 0.6471, 0.6431, 1.0],
    [0.4235, 0.4196, 0.4824, 1.0],
    [0.3451, 0.298, 0.4784, 1.0],
    [0.3529, 0.1333, 0.498, 1.0],
    [0.2745, 0, 0.498, 1.0],
    [0.098, 0, 0.502, 1.0],
    [0, 0.102, 0.6078, 1.0],
    [0, 0.102, 0.851, 1.0],
    [0, 0.2431, 0.9961, 1.0],
    [0, 0.6157, 0.9961, 1.0],
    [0, 0.8667, 0.9961, 1.0],
    [0, 0.9804, 0.8824, 1.0],
    [0.0471, 0.7529, 0.4706, 1.0],
    [0.0471, 0.7529, 0.4706, 1.0],
    [0.0863, 0.6627, 0.2824, 1.0],
    [0.1686, 0.7216, 0.1686, 1.0],
    [0.0863, 0.8902, 0.0863, 1.0],
    [0.3961, 0.9961, 0, 1.0],
    [0.898, 0.9961, 0, 1.0],
    [0.9608, 0.9608, 0.2431, 1.0],
    [0.9059, 0.8588, 0.4431, 1.0],
    [0.8784, 0.7412, 0.3451, 1.0],
    [0.9294, 0.6706, 0.1373, 1.0],
    [1, 0.502, 0, 1.0],
    [0.7843, 0.1294, 0, 1.0],
    [0.8902, 0, 0, 1.0],
    [0.6275, 0, 0, 1.0],
    [0.7333, 0.2235, 0.4, 1.0],
    [0.9961, 0.3569, 0.7647, 1.0],
    [1, 0.2039, 0.6941, 1.0],
    [0.9961, 0.1255, 0.6667, 1.0]]
temp_levs = [-29, -27, -25, -23, -21, -19, -17, -15, -13, -11, -9, -7, -5, -3, -1, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 100]





def all_grib_keys(grib_file):
    f = open(grib_file, 'rb')
    gid = eccodes.codes_grib_new_from_file(f)

    iterid = eccodes.codes_keys_iterator_new(gid, 'ls')
    
    while eccodes.codes_keys_iterator_next(iterid):
        keyname = eccodes.codes_keys_iterator_get_name(iterid)
        keyval  = eccodes.codes_get_string(gid, keyname)
        print("%s = %s" % (keyname, keyval))

    eccodes.codes_keys_iterator_delete(iterid)
    eccodes.codes_release(gid)
    f.close()
 

def grib_to_array(grib_file):
    f = open(grib_file, 'rb')
    gid = eccodes.codes_grib_new_from_file(f)
    
    # Get the data of the grid setup
    Ni = eccodes.codes_get(gid, "Ni")
    Nj = eccodes.codes_get(gid, "Nj")
    start_lat = eccodes.codes_get(gid, "latitudeOfFirstGridPointInDegrees")
    end_lat = eccodes.codes_get(gid, "latitudeOfLastGridPointInDegrees")
    start_lon = eccodes.codes_get(gid, "longitudeOfFirstGridPointInDegrees")
    end_lon = eccodes.codes_get(gid, "longitudeOfLastGridPointInDegrees")
    
    # centre around 0 longitude line
    #if start_lon >= 180:
    # start_lon = start_lon - 360
    # # if end_lon > 180:
    # end_lon = end_lon - 360
    

    # copy last column to avoid white line
    if end_lon==359.75:
        Ni=Ni+1
        end_lon=360

    # Sometimes it's not ordered top left to bottom right!
    longitudes = np.linspace(start_lon, end_lon, Ni)
    #latitudes  = np.linspace(start_lat, end_lat, Nj)
    latitudes  = np.linspace(start_lat, end_lat, Nj)
    
    xx,yy = np.meshgrid(longitudes, latitudes)    
    
    values = eccodes.codes_get_values(gid)
    if end_lon==360:
        values = values.reshape(Nj,Ni-1)
        values = np.hstack((values, values[:,[-1]]))
    
    
    eccodes.codes_release(gid)
    f.close()


    return xx,yy,values
    
    
def plot(initdate, initrun, fcsthour, domain, maptype, model):
  
    grib_folder = "/workspace/grib/"
    plot_folder = "/workspace/Maps/"


       
    if maptype=="gph500mslp":
        z_file_name =   model+"_"+initdate+initrun+"_"+fcsthour+"_z500.grib"
        p_file_name =   model+"_"+initdate+initrun+"_"+fcsthour+"_mslp.grib"
        xxgrib, yygrib, z500 = grib_to_array(grib_folder + z_file_name)
        xxgrib, yygrib, mslp = grib_to_array(grib_folder + p_file_name)
        z500 = z500 / (9.81*10)   # to dam divide by a constant, but there is a small difference depending on latitude, perhaps fix later
        mslp = mslp / 100 # to hPa
        
    if maptype=="t2m":
        t_file_name =   model+"_"+initdate+initrun+"_"+fcsthour+"_t2m.grib"
        xxgrib, yygrib, t2m = grib_to_array(grib_folder + t_file_name)
        t2m = t2m-273.15
        
    if maptype=="wind10m":
        u_file_name =   model+"_"+initdate+initrun+"_"+fcsthour+"_10u.grib"
        v_file_name =   model+"_"+initdate+initrun+"_"+fcsthour+"_10v.grib"
        xxgrib, yygrib, u = grib_to_array(grib_folder + u_file_name)
        xxgrib, yygrib, v = grib_to_array(grib_folder + v_file_name)
        wind10m = np.sqrt(u**2 + v**2)
        
    if maptype == "gph_6h_diff":
        if int(initrun)>0:
            prevrun=str("%02d" % (int(initrun)-6,))
            prevhour=str("%03d" % (int(fcsthour)+6,))
            prevdate=initdate
        if int(initrun)==0:
            prevrun="18"
            prevhour=str("%03d" % (int(fcsthour)+6,))
            prevdate=(datetime.strptime(initdate, "%Y%m%d") - timedelta(days=1)).strftime("%Y%m%d")


        grib_folder_A = grib_folder
        grib_folder_B = grib_folder

        z_file_name_A =   model+"_"+initdate+initrun+"_"+fcsthour+"_z500.grib"
        z_file_name_B =   model+"_"+prevdate+prevrun+"_"+prevhour+"_z500.grib"
        xxgrib, yygrib, z500_A = grib_to_array(grib_folder_A + z_file_name_A)
        xxgrib, yygrib, z500_B = grib_to_array(grib_folder_B + z_file_name_B)
        
        p_file_name_A =   model+"_"+initdate+initrun+"_"+fcsthour+"_mslp.grib"
        p_file_name_B =   model+"_"+prevdate+prevrun+"_"+prevhour+"_mslp.grib"
        xxgrib, yygrib, mslp_A = grib_to_array(grib_folder_A + p_file_name_A)
        xxgrib, yygrib, mslp_B = grib_to_array(grib_folder_B + p_file_name_B)
        z500_diff = (z500_A - z500_B) / 9.81 # # to dam divide by a constant, but there is a small difference depending on latitude, perhaps fix later
        mslp_diff = (mslp_A - mslp_B) / 100 # hpa

        
    if maptype == "wind10m_modeldiff":
        u_file_name_A =   "HRES48r1_"+initdate+initrun+"_"+fcsthour+"_10u.grib"
        u_file_name_B =   "HRES_"+initdate+initrun+"_"+fcsthour+"_10u.grib"
        xxgrib, yygrib, u_A = grib_to_array("/mnt/s/Meteo/grib/ECMWF/HRES48r1/"+initdate+"/"+initrun+"/" + u_file_name_A)
        xxgrib, yygrib, u_B = grib_to_array("/mnt/s/Meteo/grib/ECMWF/HRES/"+initdate+"/"+initrun+"/" + u_file_name_B)
        
        v_file_name_A =   "HRES48r1_"+initdate+initrun+"_"+fcsthour+"_10v.grib"
        v_file_name_B =   "HRES_"+initdate+initrun+"_"+fcsthour+"_10v.grib"
        xxgrib, yygrib, v_A = grib_to_array("/mnt/s/Meteo/grib/ECMWF/HRES48r1/"+initdate+"/"+initrun+"/" + v_file_name_A)
        xxgrib, yygrib, v_B = grib_to_array("/mnt/s/Meteo/grib/ECMWF/HRES/"+initdate+"/"+initrun+"/" + v_file_name_B)
        wind10m_A = np.sqrt(u_A**2 + v_A**2)
        wind10m_B = np.sqrt(u_B**2 + v_B**2)

        wind10m_diff = wind10m_A - wind10m_B


    if maptype == "t2m_modeldiff":
        t_file_name_A =   "HRES48r1_"+initdate+initrun+"_"+fcsthour+"_2t.grib"
        t_file_name_B =   "HRES_"+initdate+initrun+"_"+fcsthour+"_2t.grib"
        xxgrib, yygrib, t_A = grib_to_array("/mnt/s/Meteo/grib/ECMWF/HRES48r1/"+initdate+"/"+initrun+"/" + t_file_name_A)
        xxgrib, yygrib, t_B = grib_to_array("/mnt/s/Meteo/grib/ECMWF/HRES/"+initdate+"/"+initrun+"/" + t_file_name_B)
        
        t2m_diff = t_A - t_B


            
    if domain == "DE":
        minlat = 47.0
        maxlat = 55.5
        minlon = 5.5
        maxlon = 15.5
    
    if domain == "EU":
        minlat = 40
        maxlat = 70
        minlon = -10
        maxlon = 40

    if domain == "NH":
        minlat = 0
        maxlat = 90
        minlon = -180
        maxlon = 180
          
    fig = plt.figure(figsize=(16, 11))
    dpires = 70
    # This is (almost) identical to MetDesk Atlantic domain
    m = Basemap(width=10500000,height=6800000,
            rsphere=(6378137.00,6356752.3142),\
            resolution='i',area_thresh=2500.,projection='lcc',\
            lat_1=52.,lat_2=62,lat_0=57,lon_0=1.)


    xgrib,ygrib = m(xxgrib, yygrib)
    
    if maptype=="gph500mslp":
        m.drawcoastlines()
        m.drawcountries()
        
  
        MetDesk_gph_ticks = [480, 484, 488, 492, 496, 500, 504, 508, 512, 516, 520, 524, 528, 532, 536, 540, 544, 548, 552, 556, 560, 564, 568, 572, 576, 580, 584, 588, 592, 596, 600]
        z500=z500-2
    
        cs = m.contourf(xgrib, ygrib, z500, MetDesk_gph_ticks, cmap=z500_cmap)
            
        pres_levs = np.arange(920,1080,2)
        # < 1000 = red
        pres_cols = ["#FF0000"]*45
        pres_cols += ["#000000"]*6
        pres_cols += ["#0000FF"]*29
    
        m.contour(xgrib, ygrib, mslp, pres_levs, linewidths=[1.5,0.4,0.4,0.4,0.4], colors=pres_cols)
        #plt.show()
        plt.tight_layout()


        validtimestr = datetime.strftime(datetime.strptime(initdate, '%Y%m%d')+timedelta(hours=int(fcsthour)+int(initrun)), '%a %Y-%m-%d %H:%M UTC')
        plt.annotate(validtimestr, (0,1), size=10, xycoords='axes fraction', backgroundcolor='w', color='black')        
        plt.title(model+" gph500 + mslp "+initdate+" "+initrun+"z +"+fcsthour+"HR")
        plt.savefig(plot_folder+model+"_gph500mslp_"+initdate+initrun+"_"+fcsthour+".png", dpi=dpires)
    
    if maptype=="gph_6h_diff":
        m.drawcoastlines()
        m.drawcountries()
        
        z500_diff=z500_diff/9.81
        #MetDesk_gph_ticks = [480, 484, 488, 492, 496, 500, 504, 508, 512, 516, 520, 524, 528, 532, 536, 540, 544, 548, 552, 556, 560, 564, 568, 572, 576, 580, 584, 588, 592, 596, 600]
        #z500=z500-12
    
        z_diff_levs = np.arange(-20,20,2)
        cs = m.contourf(xgrib, ygrib, z500_diff, gphdiff_levs, colors=MetDesk_gphdiff_cols)            
        #pres_levs = 
        pres_levs = np.concatenate( (np.arange(-40,0,2), np.arange(2,42,2)) )
        pres_cols = ['#404080']*int(len(pres_levs)/2)
        pres_cols += ['#804040']*int(len(pres_levs)/2)        
        pres_cols = ['#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#0A0AF0','#3232F0','#4B4BE1','#6464DC','#7D7DD7','#9696D2','#AFAFCD','#C8C8C8','#C8C8C8','#CDAFAF','#D29696','#D77D7D','#D25A5A','#CD4B4B','#C83232','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A','#C80A0A']
        m.contour(xgrib, ygrib, mslp_diff, pres_levs, linewidths=[1.2,0.6,0.6,0.6,0.6], colors=pres_cols)
        #plt.show()
        plt.tight_layout()
        
        validtimestr = datetime.strftime(datetime.strptime(initdate, '%Y%m%d')+timedelta(hours=int(fcsthour)+int(initrun)), '%a %Y-%m-%d %H:%M UTC')
        plt.annotate(validtimestr, (0,1), size=10, xycoords='axes fraction', backgroundcolor='w', color='black')
        plt.title("PANGUGFS difference vs 6hr ago "+initdate+" 00z +"+fcsthour+"HR    " )
        plt.savefig(plot_folder+model+"_gph500mslpdiff_"+initdate+initrun+"_"+fcsthour+".png", dpi=dpires)    

    
    if maptype=="t2m":
        m.drawcoastlines()
        m.drawcountries()
               

        cs = m.contourf(xgrib, ygrib, t2m, temp_levs, colors=MetDesk_temp_cols)
        plt.tight_layout()
               
        Nlongrid = 40
        Nlatgrid = 20
        longrid = np.linspace(-40, 40, Nlongrid)
        latgrid = np.linspace(30, 70, Nlatgrid)
                
        u_grid = np.empty(0)
        v_grid = np.empty(0)
        for llat in latgrid:
            for llon in longrid:
                x,y = m(llon,llat)
                pointnumber = int(t2m[np.absolute(yygrib[:,0] - llat).argmin(),np.absolute(xxgrib[0] - llon).argmin()])
                fcolor='#000000'
                if pointnumber<-5:
                    fcolor='#ffffff'
                if pointnumber<-20:
                    fcolor='#0000ee'
                if pointnumber>30:
                    fcolor='#ffffff'                
                plt.text(x,y, pointnumber, fontsize=8, alpha=0.9, color=fcolor)

        
        validtimestr = datetime.strftime(datetime.strptime(initdate, '%Y%m%d')+timedelta(hours=int(fcsthour)+int(initrun)), '%a %Y-%m-%d %H:%M UTC')
        plt.annotate(validtimestr, (0,1), size=10, xycoords='axes fraction', backgroundcolor='w', color='black')        
        plt.title(model+" temp 2m "+initdate+" 00z +"+fcsthour+"HR")
        plt.savefig(plot_folder+model+"_t2m_"+initdate+initrun+"_"+fcsthour+".png", dpi=dpires)    
    

    if maptype=="t2m_modeldiff":
        m.drawcoastlines()
        m.drawcountries()
        
#        winddiff_levs = np.arange(-40,40,2) 
        cs = m.contourf(xgrib, ygrib, t2m_diff, winddiff_levs, colors=MetDesk_winddiff_cols)
        plt.tight_layout()
  
        Nlongrid = 40
        Nlatgrid = 20
        longrid = np.linspace(-40, 40, Nlongrid)
        latgrid = np.linspace(30, 70, Nlatgrid)
                
        v_grid = np.empty(0)
        for llat in latgrid:
            for llon in longrid:
                x,y = m(llon,llat)
                pointnumber = int(t2m_diff[np.absolute(yygrib[:,0] - llat).argmin(),np.absolute(xxgrib[0] - llon).argmin()])                    
                plt.text(x,y, pointnumber, fontsize=8, alpha=0.9)
      
        validtimestr = datetime.strftime(datetime.strptime(initdate, '%Y%m%d')+timedelta(hours=int(fcsthour)+int(initrun)), '%a %Y-%m-%d %H:%M UTC')
        plt.annotate(validtimestr, (0,1), size=10, xycoords='axes fraction', backgroundcolor='w', color='black')    
        plt.title("HRES48r1  -minus-  HRES "+initdate+" "+initrun+"z +"+fcsthour+"HR")
        plt.savefig(plot_folder+model+"_t2mdiff_"+initdate+initrun+"_"+fcsthour+".png", dpi=dpires)    
    
    
    
    
    if maptype=="wind10m":    
            m.drawcoastlines()
            m.drawcountries()
            
            cs = m.contourf(xgrib, ygrib, wind10m, MetDesk_wind_ticks, colors=MetDesk_wind_cols)
            plt.tight_layout()
            
            # # this needs cleaning up especially the variable names are super ocnfusing
            # # draw number every 0.5 x 0.5 degree
            Nlongrid = 40
            Nlatgrid = 20
            longrid = np.linspace(-40, 40, Nlongrid)
            latgrid = np.linspace(30, 70, Nlatgrid)
            
            u_grid = np.empty(0)
            v_grid = np.empty(0)
            for llat in latgrid:
                for llon in longrid:
                    x,y = m(llon,llat)
                    pointnumber = int(wind10m[np.absolute(yygrib[:,0] - llat).argmin(),np.absolute(xxgrib[0] - llon).argmin()])
                    plt.text(x,y, pointnumber, fontsize=9)
            #         u_grid = np.append(u_grid, u[np.absolute(yygrib[:,0] - llat).argmin(),np.absolute(xxgrib[0] - llon).argmin()])
            #         v_grid = np.append(v_grid, v[np.absolute(yygrib[:,0] - llat).argmin(),np.absolute(xxgrib[0] - llon).argmin()])
            # u_grid = u_grid.reshape(Nlatgrid, Nlongrid)
            # v_grid = v_grid.reshape(Nlatgrid, Nlongrid)
            
            # xxgrid,yygrid = np.meshgrid(longrid,latgrid)
            # m.quiver(xxgrid, yygrid, u_grid, v_grid, latlon=True, color='#3b3b3b', pivot='middle', alpha=0.75, width=0.001)
            
        
            validtimestr = datetime.strftime(datetime.strptime(initdate, '%Y%m%d')+timedelta(hours=int(fcsthour)+int(initrun)), '%a %Y-%m-%d %H:%M UTC')
            plt.annotate(validtimestr, (0,1), size=10, xycoords='axes fraction', backgroundcolor='w', color='black')        
            plt.title(model+" 10mwind "+initdate+" 00z +"+fcsthour+"HR")
            plt.savefig(plot_folder+model+"_wind10m_"+initdate+initrun+"_"+fcsthour+".png", dpi=dpires)    
    
   
    
    if maptype=="wind10m_modeldiff":
        m.drawcoastlines()
        m.drawcountries()
        
#        winddiff_levs = np.arange(-40,40,2) 
        cs = m.contourf(xgrib, ygrib, wind10m_diff, winddiff_levs, colors=MetDesk_winddiff_cols)
        plt.tight_layout()
  
        Nlongrid = 40
        Nlatgrid = 20
        longrid = np.linspace(-40, 40, Nlongrid)
        latgrid = np.linspace(30, 70, Nlatgrid)
                
        u_grid = np.empty(0)
        v_grid = np.empty(0)
        for llat in latgrid:
            for llon in longrid:
                x,y = m(llon,llat)
                pointnumber = int(wind10m_diff[np.absolute(yygrib[:,0] - llat).argmin(),np.absolute(xxgrib[0] - llon).argmin()])                    
                plt.text(x,y, pointnumber, fontsize=8, alpha=0.9)
      
        validtimestr = datetime.strftime(datetime.strptime(initdate, '%Y%m%d')+timedelta(hours=int(fcsthour)+int(initrun)), '%a %Y-%m-%d %H:%M UTC')
        plt.annotate(validtimestr, (0,1), size=10, xycoords='axes fraction', backgroundcolor='w', color='black')    
        plt.title("HRES48r1  -minus-  HRES "+initdate+" 00z +"+fcsthour+"HR")
        plt.savefig(plot_folder+model+"_wind10mdiff_"+initdate+initrun+"_"+fcsthour+".png", dpi=dpires)    
    
    


    
def main(args):   
    initdate = args.date
    initrun = args.run
    fcsthour = args.hour
    domain = args.domain
    maptype = args.maptype
    model = args.model
    
    plot(initdate, initrun, fcsthour, domain, maptype, model)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-date', type=str, required=False)
    parser.add_argument('-run', type=str, required=False)
    parser.add_argument('-hour', type=str, required=False)    
    parser.add_argument('-domain', type=str, required=False, default='EU')
    parser.add_argument('-maptype', type=str, required=False, default='gph500mslp')
    parser.add_argument('-model', type=str, required=False, default='HRES48r1')
    
    args = parser.parse_args()
    main(args)
