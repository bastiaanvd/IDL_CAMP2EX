; NAME:
;   convert_L2Cloud_2_ict
;
; PURPOSE:
;   converts RSP L2 hdf files to ICARTT format
;
; :Dependencies:
;    uses H5_PARSE
;
; :Categories:
;   remote sensing
;
;  :program outline
;   - loop over dates
;   - 
;
; :Examples:
;     
;
; :Author:
;    Bastiaan van Diedenhoven
;    Research Scientist
;    Columbia University Center for Climate System Research & NASA GISS
;    2880 Broadway
;    New York, NY 10025
;    Tel: +1 212 678 5512
;    Email: bvandiedenhoven@gmail.com
;    Email: bv2154@columbia.edu
;
; :History:
;     created: 13 July, 2020
;     updated21 July, 2020: added cirrus mask, 
;---------------------------------
;switches
switch_print_vars=0            ; set to print out all variables in hdf file
switch_save=1; set to save to file
switch_print=1                  ;set to print to screen
add_cirrus_mask=1

;settings:
campaign='CAMP2Ex'
platform='NASA P3'
path='../DATA/L2_V003/
prefix='RSP1-P3_L2-RSPCLOUD-Clouds_'
prefix_folder='RSP1_'
end_folder='_L2_V003/'
;prefix='CAMP2EX-RSP1-CLD_P3B_'
;prefix_folder='CAMP2EX-RSP1-CLD_P3B_'
;end_folder='_R2/'


prefix_cirrus_mask_folder='CAMP2EX-RSP1-SPNCirrusMask_P3B_'
prefix_cirrus_mask_file=  'CAMP2EX-RSP1-SPNCirrusMask_P3B_'
cirrus_mask_version='R3'
paths_cirrusmask='./HDF/'


dates=['20190916']
ndates=n_elements(dates)

path_out='./ICT/'
prefix_out=campaign+'-RSP-CLOUD_P3_'
revision='R0'
ext='.ict'

settings_file='settings_convert_L2cloud_2_ict.csv'
settings=read_csv(settings_file,N_TABLE_HEADER=1,TABLE_HEADER=settings_header)
campaign=STRCOMPRESS(settings.field01,/REMOVE_ALL)
dates=STRCOMPRESS(settings.field02,/REMOVE_ALL)
path_rsp=STRCOMPRESS(settings.field03,/REMOVE_ALL)
prefix_folder=STRCOMPRESS(settings.field04,/REMOVE_ALL)
end_folder=STRCOMPRESS(settings.field05,/REMOVE_ALL)
prefix_file=STRCOMPRESS(settings.field06,/REMOVE_ALL)

path_out=STRCOMPRESS(settings.field07,/REMOVE_ALL)
prefix_file_out=STRCOMPRESS(settings.field08,/REMOVE_ALL)
revision=STRCOMPRESS(settings.field09,/REMOVE_ALL)

add_cirrus_mask=ROUND(settings.field10)
stop
;IF(add_cirrus_mask eq 1)THEN BEGIN
;        path_SPN=STRCOMPRESS(settings.field10,/REMOVE_ALL)
ndates=n_elements(dates)


;--- selection of variables:

time_start_folder=6               ; time_start
time_start_var=27               ; time_start
timeformat='(F10.2)'
stop, 'fix this'

variable_names=[$ 
        'COLLOCATED_LATITUDE',$
        'COLLOCATED_LONGITUDE',$
        'CLOUD_QUALITY',$
        'CLOUD_TOP_ALTITUDE',$
        'CLOUD_LIQUID_INDEX',$
        'CLOUD_BOW_OPTICAL_THICKNESS',$; this is not used!
        'CLOUD_BOW_DROPLET_EFFECTIVE_RADIUS',$
        'CLOUD_BOW_DROPLET_EFFECTIVE_VARIANCE',$
        'CLOUD_BI_SPEC_PARTICLE_EFFECTIVE_RADIUS',$
        'CLOUD_BI_SPEC_PARTICLE_EFFECTIVE_RADIUS'$ 
]

folder_names=[$
        'GEOMETRY',$ 
        'GEOMETRY'  ,$     
        'DATA',$ 
        'DATA',$ 
        'DATA',$ 
        'DATA',$ 
        'DATA',$ 
        'DATA',$ 
        'DATA',$ 
        'DATA'$
]

select_item=[$,
        0,$;lat
        0,$;lon
        0,$;quality
        1,$ ;cth
        1,$ ;liquid index
        0,$ ;cot
        0,$  ;reff_pol    
        0,$  ;veff_pol    
        -1,$  ;reff_1590
        -2$  ;reff_2260    
]



short_names=[$
        'Lat',$
        'Lon',$
;        'Cloud_mask',$        
        'Quality_flag',$        
        'CTH',$ 
        'Liquid_index',$
        'COT' ,     $ 
        'Reff_pol' ,$
        'Veff_pol' ,$
        'Reff_rad_1590', $
        'Reff_rad_2260' $
        ]



description=[$
        '',$
        '',$
;        'if both bits (0+1) or (2+4) set, then cloud detected. If bit 3 set cloud detected at 1880 nm',$
        'bit 0: only 1 test detected cloud; bit 1 or 2: bi-spectral size extrapolation; bit 3,4,5 or 6: COT extrapolation; fill value = no cloud',$
        'multi-angle parralax',$
        'at 865nm, generally <0.3 indicates ice top',$
        'Using polarimetry drop size or otherwise bi-spectral 2260nm size, or otherwise reff=10',$
        'Polarimetry using 865 nm',$
        'Polarimetry using 865 nm',$
        'bi-spectral using 1590 nm',$
        'bi_spectral using 2260 nm'$
]


formats=[$
        '(F8.4)',$              ;lat
        '(F8.4)',$              ;lon        
;        '(I3)',$              ;mask
        '(I3)',$              ;quality
        '(I5)',$              ;cth
        '(F8.3)',$              ;cot        
        '(F7.2)',$              ;cot
        '(F7.2)',$              ;reff_pol
        '(F8.3)',$              ;veff_pol
        '(F7.2)',$              ;reff
        '(F7.2)'$              ;reff
        ]

nvar=n_elements(select_data_vars)
nvar_write=nvar
IF(add_cirrus_mask)THEN nvar_write=nvar_write+1

FOR Idate=0,ndates-1 DO BEGIN

   date=dates[idate]
   files=FILE_SEARCH(path+prefix_folder+date+end_folder+prefix+date+'*.h5',COUNT=nfiles)
   
   IF(nfiles eq 0)THEN BEGIN
      print,'no file found for ',date
      print,path+prefix_folder+date+end_folder+prefix+date+'*.h5'
      CONTINUE
   ENDIF
   filename=files[0]
   print,'processing file ',FILE_BASENAME(filename)
   data=H5_PARSE(filename,/READ)

   IF(switch_print_vars)THEN BEGIN
      print,'List of variables in HDF file:'
      FOR ivar=6,57 DO print,ivar,' ',data.(ivar)._name

     print,'List of variables in HDF file data folder:'
     FOR ivar=6,30 DO print,ivar,' ',data.data.(ivar)._name;,data.data.(ivar).units._data
                 
     print,'List of variables in HDF file geometry folder:'
     FOR ivar=6,22 DO print,ivar,' ',data.geometry.(ivar)._name


      stop
   ENDIF

   select_folder=INTARR(nvar)
   select_data_vars=INTARR(nvar)
        
   FOR ivar=0,nvar-1 DO BEGIN
        select_folder[ivar]=where(TAG_NAMES(data) eq folder_names[ivar])
        select_data_vars[ivar]=where(TAG_NAMES(data.(select_folder[ivar])) eq variable_names[ivar])
   ENDFOR

   year=STRMID(date,0,4)
   month=STRMID(date,4,2)
   day=STRMID(date,6,2)
   CALDAT,systime(/JULIAN,/UTC),m_now,d_now,y_now

   header='xx , 1001'
   header=[header,$
           'van Diedenhoven, Bastiaan',$
           'NASA Goddard Institute for Space Studies', $
           'RSP cloud retrievals', $
           campaign]
   
   header=[header,$
          '1, 1']
   
   header=[header,$
           year+', '+month+', '+day+', '+STRING(y_now,FORMAT='(I4)')+', '+STRING(m_now,FORMAT='(I2.2)')+', '+STRING(d_now,FORMAT='(I2.2)')]
   

   header=[header,$
           '0']                 ;Data Interval
   
   header=[header,$
           'Time_start, seconds']
   
   header=[header,$
           STRING(nvar_write+2,format='(I2)')] ;Number of variables + UTC_stop & UTC_mid
   
      scale_srt='1'
   for ivar=1,nvar_write-1 DO scale_srt=scale_srt+', 1'
   
   header=[header,$
           scale_srt]
   
   miss_srt='-999'
      
   ;for ivar=1,nvar_write-1 DO miss_srt=miss_srt+', -999'
   for ivar=1,nvar-1 DO miss_srt=miss_srt+', '+STRING(data.(select_folder[ivar]).(select_data_vars[ivar]).FILL_VALUE._data,FORMAT='(I5)')
   IF(add_cirrus_mask)THEN miss_srt=miss_srt+', -999'
   
   
   header=[header,$
           miss_srt]


   
   FOR ivar=0,nvar-1 DO BEGIN
      var_name=data.(select_folder[ivar]).(select_data_vars[ivar])._name
 ;       IF(ivar ne 3)THEN var_name=data.(select_folder[ivar]).(select_data_vars[ivar]).long_name._data ELSE var_name='cloud top height'
;      name_parts=STRSPLIT(var_name,'_')
;      short_names[ivar]=STRMID(var_name,name_parts[1],STRLEN(var_name)-name_parts[1]); chops off bit before first _
      icheckunits=where(TAG_NAMES(data.(select_folder[ivar]).(select_data_vars[ivar])) eq 'UNITS')
      
      IF(icheckunits ne -1)THEN var_units=data.(select_folder[ivar]).(select_data_vars[ivar]).units._data ELSE var_units='dimensionless'

      header=[header,$
              short_names[ivar]+', '+var_units+', '+var_name+' '+description[ivar]]
                                ;print,short_names(ivar)+', '+var_units(ivar)+', '+var_names(ivar)
   ENDFOR

        IF(add_cirrus_mask)THEN  header=[header,$
                                        'Cirrus_mask, none, SPN cirrus mask (1= clear, 0= cirrus detected)']

      header=[header,$
           '0']                 ;#special comments (Unique to 1 file)
   
   comments='PI_CONTACT_INFO: Address: 2880 Broadway, New York, NY 10025; email: bv2154@columbia.edu'
   
   comments=[comments,$
             'PLATFORM: '+platform]
   
   comments=[comments,$
             'LOCATION: Latitute, Longitude included in file. Approximately directly under flight path.']  

   comments=[comments,$
             'ASSOCIATED_DATA: '+FILE_BASENAME(filename) ]

   comments=[comments,$
             'INSTRUMENT_INFO: Research Scanning Polarimeter (RSP)']
   
   comments=[comments,$
             'DATA_INFO: Cloud properties retrieved using RSP measurements']
   comments=[comments,$
             'References: ']
   comments=[comments,$
             'UNCERTAINTY: See references']
   comments=[comments,$
             'ULOD_FLAG: -7777']
   comments=[comments,$
             'ULOD_VALUE: None']
   comments=[comments,$
             'DM_CONTACT_INFO: Bastiaan Van Diedenhoven <bv2154@columbia.edu>, Cairns, Brian (GISS-6110) <brian.cairns@nasa.gov>, Wasilewski, Andrzej P (GISS-611.0)[SciSpace LLC] <andrzej.p.wasilewski@nasa.gov>, Mikhail Alexandrov <mda14@columbia.edu>']
   comments=[comments,$
             'PROJECT_INFO: '+campaign+' mission']
   comments=[comments,$
             'STIPULATIONS_ON_USE: Please contact PI or DM for assistance for usage.']
   comments=[comments,$
             'OTHER_COMMENTS: Reference CTH: Sinclair et al. (2017; doi:10.5194/amt-10-2361-2017)']
   comments=[comments,$  
            'References COT,REFF: Alexandrov et al. (2012, doi:10.1016/j.rse.2012.07.012)']
   comments=[comments,$  
            'Reference liquid_index: van Diedenhoven et al. (2012, doi:10.1175/JAS-D-11-0314.1)']
   comments=[comments,$  
            'Please also read the cloud readme text']
         
   comments=[comments,$
             'REVISION: '+revision]
   
   
   ncomments=n_elements(comments)
   header=[header,$
           STRING(ncomments+1,format='(I2)')] ;number of normal comments
   
   header=[header,$
           comments]

   short_names_line='Time_start   '
   FOR ivar=0,nvar-1 DO short_names_line=short_names_line+', '+short_names[ivar]
        IF(add_cirrus_mask)THEN short_names_line=short_names_line+', Cirrus_mask'
   header=[header,$
           short_names_line]

   nheader=n_elements(header)
   header[0]=STRING(nheader, FORMAT='(I3)')+' , 1001'


   IF(switch_save)THEN BEGIN
      OPENW,LUN,path_out+prefix_out+date+'_'+revision+ext,/GET_LUN
      for ihead= 0,nheader-1 DO printF,lun,header[ihead]
   ENDIF
   
   IF(switch_print)THEN for ihead= 0,nheader-1 DO print,header[ihead]
   
FOR Ifile=0,nfiles-1 DO BEGIN
        filename=files[Ifile]
        print,'processing file ',FILE_BASENAME(filename)
        data=H5_PARSE(filename,/READ)
        IF(add_cirrus_mask)THEN BEGIN
                parts=STRSPLIT(filename,'_',/EXTRACT)
                cirrus_mask_folder=prefix_cirrus_mask_folder+date+'/'
                cirrus_mask_file=prefix_cirrus_mask_file+parts[6]+'_'+cirrus_mask_version+'.h5'
                check_cirrus_file=FILE_SEARCH(paths_cirrusmask+cirrus_mask_folder+cirrus_mask_file,count=cirrus_file_check)
                IF(cirrus_file_check eq 1)THEN data_cirrus=H5_PARSE(paths_cirrusmask+cirrus_mask_folder+cirrus_mask_file,/READ)
                
        ENDIF
     

   ndata=n_elements(data.(time_start_folder).(time_start_var)._data)
   FOR idata=0,ndata-1 DO BEGIN

      print_line=STRING(data.(time_start_folder).(time_start_var)._data[idata],FORMAT=timeformat)
            
      FOR ivar=0,nvar-1 DO BEGIN
     
        CASE 1 OF     
                (select_data_vars[ivar] eq 19):BEGIN ;cot
                        cots=[data.data.Cloud_Bow_Optical_Thickness._data[idata],data.data.Cloud_Bi_Spec_Optical_Thickness._data[1,idata],data.data.Cloud_Default_Size_Optical_Thickness._data[idata]]
                        i999=where(cots gt 0,n999)
                        cot1=MIN([cots[MIN(i999)],256.])
                        line_print=STRING(cot1,FORMAT=formats[ivar])
                   END
                (select_folder[ivar]) eq 6 and (select_data_vars[ivar] eq 7): BEGIN ;reff_rad
                        reff1=data.(select_folder[ivar]).(select_data_vars[ivar])._data[-select_item[ivar]-1,idata]
                        reff1=MIN([reff1,30])
                        IF(reff1 ne -999)THEN reff1=MAX([5,reff1])
                        line_print=STRING(reff1,FORMAT=formats[ivar]) 
                   END   
                ELSE:   BEGIN
                                IF(select_item[ivar] le -1)THEN $
                                        line_print=STRING(data.(select_folder[ivar]).(select_data_vars[ivar])._data[-select_item[ivar]-1,idata],FORMAT=formats[ivar]) 
                                IF(select_item[ivar] ge 1)THEN $
                                        line_print =STRING(data.(select_folder[ivar]).(select_data_vars[ivar])._data[idata,select_item[ivar]-1],FORMAT=formats[ivar]) 
                                IF(select_item[ivar] eq 0)THEN $
                                        line_print =STRING(data.(select_folder[ivar]).(select_data_vars[ivar])._data[idata],FORMAT=formats[ivar]) 
                        END

        ENDCASE
        IF(ivar gt 4 and data.data.Cloud_Top_Altitude._data[idata] lt 0)THEN line_print=STRING(-999,FORMAT=formats[ivar])
        print_line=print_line+', '+ line_print;first cot gt 0
        
        ENDFOR
      IF(add_cirrus_mask)THEN $
        IF(cirrus_file_check eq 1) THEN print_line=print_line+', '+STRING(data_cirrus.CIRRUS_MASK._data[idata],FORMAT='(I4)') ELSE print_line=print_line+', -999'

      IF(switch_print)THEN print,idata,print_line
      IF(switch_save)THEN  printF,lun, print_line
      ; if(MIN(i999) eq 0 and data.data.Cloud_Bow_Droplet_Effective_Radius._data[idata] lt 0)THEN stop
 

ENDFOR

ENDFOR

   IF(switch_save)THEN FREE_LUN,LUN
ENDFOR


   ;stop





end
