; NAME:
;   convert_L2Cloud_2_ict
;
; PURPOSE:
;   converts RSP L2 hdf cloud files to ICARTT format
;
; :Dependencies:
;    uses H5_PARSE
;
; :Categories:
;   remote sensing
;
;  :program outline
;   - get settings
;   - loop over dates
;   - loop over files
;   - output file
;
; :Usage:
;   To run: convert_L2cloud_2_ict,settings_file
;   Settings_file.csv contains paths and dates to process 
;   Settings_file.csv also contains output folder, etc.
;   Settings_file.csv also cirrus above aricraft mask on/off switch and contains path to cirrusmask data

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
;     updated 21 July, 2020: added cirrus mask, 
;     updated 6 April, 2021: added settings file
;---------------------------------
;switches
pro convert_L2cloud_2_ict,settings_file,variables_file,$
        switch_show_vars=switch_show_vars,$ 
        switch_no_save=switch_no_save, $ 
        switch_print=switch_print

;switch_show_vars=1            ; set to print out all variables in hdf file and stop
;switch_no_save=1; set to NOT save to file
;switch_print=1                  ;set to print info to screen


;settings_file='settings_convert_L2cloud_2_ict.csv'
;variables_file='variables_convert_L2cloud_2_ict.csv'

;reading settings file:
settings=read_csv(settings_file,N_TABLE_HEADER=1,TABLE_HEADER=settings_header)
campaign=STRCOMPRESS(settings.field01,/REMOVE_ALL)
dates=STRCOMPRESS(settings.field02,/REMOVE_ALL)
path_rsp=STRCOMPRESS(settings.field03,/REMOVE_ALL)
prefix_folder=STRCOMPRESS(settings.field04,/REMOVE_ALL)
end_folder=STRCOMPRESS(settings.field05,/REMOVE_ALL)
prefix_file=STRCOMPRESS(settings.field06,/REMOVE_ALL)

path_out=STRCOMPRESS(settings.field07,/REMOVE_ALL)
prefix_out=STRCOMPRESS(settings.field08,/REMOVE_ALL)
revision=STRCOMPRESS(settings.field09,/REMOVE_ALL)

add_cirrus_mask=FIX(settings.field10)

ndates=n_elements(dates)

ext='.ict'

;--- selection of variables:

variables_data=read_csv(variables_file,N_TABLE_HEADER=1,TABLE_HEADER=settings_header)

time_variable=variables_data.(0)[0]
time_folder=variables_data.(1)[0]
timeformat=variables_data.(3)[0]
time_short_name=variables_data.(4)[0]

nvar=n_elements(variables_data.(0))-1
variable_names=variables_data.(0)[1:nvar]
folder_names=variables_data.(1)[1:nvar]
select_item=variables_data.(2)[1:nvar]
formats=variables_data.(3)[1:nvar]
short_names=variables_data.(4)[1:nvar]
standard_names=variables_data.(5)[1:nvar]
description=variables_data.(6)[1:nvar]


FOR Idate=0,ndates-1 DO BEGIN

        date=dates[idate]
        files=FILE_SEARCH(path_rsp[idate]+prefix_folder[idate]+date+end_folder[idate]+prefix_file[idate]+date+'*.h5',COUNT=nfiles)

        IF(nfiles eq 0)THEN BEGIN
                print,'no file found for ',date
                print,path_rsp[idate]+prefix_folder[idate]+date+end_folder[idate]+prefix_file[idate]+date+'*.h5'
                CONTINUE
        END
        filename=files[0]
        print,'processing date ',date
        data=H5_PARSE(filename,/READ)

        IF KEYWORD_SET(switch_show_vars)THEN BEGIN
                print,'List of variables in HDF file:'
                FOR ivar=6,57 DO print,ivar,' ',data.(ivar)._name

                print,'List of variables in HDF file data folder:'
                FOR ivar=6,30 DO print,ivar,' ',data.data.(ivar)._name;,data.data.(ivar).units._data
                                
                print,'List of variables in HDF file geometry folder:'
                FOR ivar=6,22 DO print,ivar,' ',data.geometry.(ivar)._name
                stop
        ENDIF

        time_start_folder=where(TAG_NAMES(data) eq time_folder)
        time_start_var=where(TAG_NAMES(data.(time_start_folder)) eq time_variable)

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

        nvar_write=nvar
        IF(add_cirrus_mask[idate])THEN nvar_write=nvar+1


        header='xx , 1001'
        header=[header,$
                'van Diedenhoven, Bastiaan',$
                'NASA Goddard Institute for Space Studies', $
                'RSP cloud retrievals', $
                data.experiment._data[0]]

        header=[header,$
                '1, 1']

        header=[header,$
                year+', '+month+', '+day+', '+STRING(y_now,FORMAT='(I4)')+', '+STRING(m_now,FORMAT='(I2.2)')+', '+STRING(d_now,FORMAT='(I2.2)')]


        header=[header,$
                '0.86']                 ;Data Interval

        header=[header,$
                'Time_start, seconds']

        header=[header,$
                STRING(nvar_write,format='(I2)')] ;Number of variables 

        scale_srt='1'
        for ivar=1,nvar_write-1 DO scale_srt=scale_srt+', 1'

        header=[header,$
                scale_srt]

        miss_srt='-999'

        for ivar=1,nvar-1 DO miss_srt=miss_srt+', -999'
        ;for ivar=1,nvar-1 DO miss_srt=miss_srt+', '+STRING(data.(select_folder[ivar]).(select_data_vars[ivar]).FILL_VALUE._data,FORMAT='(I5)')
        ;ICT files cannot handle fill values of 255 for flags so put all to -999!
        IF(add_cirrus_mask[idate])THEN miss_srt=miss_srt+', -999'

        header=[header,$
                miss_srt]

        FOR ivar=0,nvar-1 DO BEGIN
                var_name=data.(select_folder[ivar]).(select_data_vars[ivar])._name
                icheckunits=where(TAG_NAMES(data.(select_folder[ivar]).(select_data_vars[ivar])) eq 'UNITS')

                IF(icheckunits ne -1)THEN var_units=data.(select_folder[ivar]).(select_data_vars[ivar]).units._data ELSE var_units='dimensionless'

                header=[header,$
                        short_names[ivar]+', '+var_units+', '+standard_names[ivar]+', '+var_name+' '+description[ivar]]
                                        ;print,short_names(ivar)+', '+var_units(ivar)+', '+var_names(ivar)
        ENDFOR

        IF(add_cirrus_mask[idate])THEN  header=[header,$
                                        'Cirrus_mask, none, none, SPN cirrus mask (1= clear, 0= cirrus detected)']

        header=[header,$
                '0']                 ;#special comments (Unique to 1 file)

        comments='PI_CONTACT_INFO: Address: 2880 Broadway, New York, NY 10025; email: bv2154@columbia.edu, bvandiedenhoven@gmail.com'

        comments=[comments,$
                'PLATFORM: '+data.PLATFORM_DESCRIPTION._data]

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
                'LLOD_FLAG: -8888']
        comments=[comments,$
                'LLOD_VALUE: None']
        comments=[comments,$
                'DM_CONTACT_INFO: Wasilewski, Andrzej P (GISS-611.0)[SciSpace LLC] <andrzej.p.wasilewski@nasa.gov>']
        comments=[comments,$
                'PROJECT_INFO: '+data.experiment._data[0]+' mission']
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
                'REVISION: '+revision[idate]]


        ncomments=n_elements(comments)
        header=[header,$
                STRING(ncomments+1,format='(I2)')] ;number of normal comments

        header=[header,$
                comments]

        short_names_line=time_short_name
        FOR ivar=0,nvar-1 DO short_names_line=short_names_line+', '+short_names[ivar]
        IF(add_cirrus_mask[idate])THEN short_names_line=short_names_line+', Cirrus_mask'
        header=[header,$
                short_names_line]

        nheader=n_elements(header)
        header[0]=STRING(nheader, FORMAT='(I3)')+' , 1001'


        IF ~KEYWORD_SET(switch_no_save)THEN BEGIN
                OPENW,LUN,path_out[idate]+prefix_out[idate]+date+'_'+revision[idate]+ext,/GET_LUN
                for ihead= 0,nheader-1 DO printF,lun,header[ihead]
        ENDIF

        IF KEYWORD_SET(switch_print)THEN for ihead= 0,nheader-1 DO print,header[ihead]

        ;----start writing data
        IF(add_cirrus_mask[idate])THEN BEGIN
                path_cirrusmask=STRCOMPRESS(settings.field11[idate],/REMOVE_ALL)
                prefix_cirrus_mask_file=STRCOMPRESS(settings.field12[idate],/REMOVE_ALL)
                cirrus_mask_version=STRCOMPRESS(settings.field13[idate],/REMOVE_ALL)
        ENDIF

        FOR Ifile=0,nfiles-1 DO BEGIN 
                filename=files[Ifile]
                print,'processing file ',FILE_BASENAME(filename)
                data=H5_PARSE(filename,/READ)
                IF(add_cirrus_mask[idate])THEN BEGIN
                        parts=STRSPLIT(filename,'_',/EXTRACT)
                        parts2=STRSPLIT(parts[6],'T',/EXTRACT)
                        parts3=STRSPLIT(parts2[1],'Z',/EXTRACT)

                        cirrus_mask_folder=prefix_cirrus_mask_file+date+'_'+cirrus_mask_version+'/'
                        cirrus_mask_file=prefix_cirrus_mask_file+parts2[0]+parts3[0]+'_'+cirrus_mask_version+'.h5'
                        check_cirrus_file=FILE_SEARCH(path_cirrusmask+cirrus_mask_folder+cirrus_mask_file,count=cirrus_file_check)
                        IF(cirrus_file_check eq 1)THEN data_cirrus=H5_PARSE(path_cirrusmask+cirrus_mask_folder+cirrus_mask_file,/READ)
                ENDIF


                ndata=n_elements(data.(time_start_folder).(time_start_var)._data)
                FOR idata=0,ndata-1 DO BEGIN

                        print_line=STRING(data.(time_start_folder).(time_start_var)._data[idata],FORMAT=timeformat)
                                
                        FOR ivar=0,nvar-1 DO BEGIN

                                CASE 1 OF     
                                        (variable_names[ivar] eq 'CLOUD_BOW_OPTICAL_THICKNESS'):BEGIN ;cot
                                                cots=[data.data.Cloud_Bow_Optical_Thickness._data[idata],data.data.Cloud_Bi_Spec_Optical_Thickness._data[1,idata],data.data.Cloud_Default_Size_Optical_Thickness._data[idata]]
                                                i999=where(cots gt 0,n999)
                                                cot1=MIN([cots[MIN(i999)],256.])
                                                line_print=STRING(cot1,FORMAT=formats[ivar])
                                                END
                                        (variable_names[ivar] eq 'CLOUD_BI_SPEC_PARTICLE_EFFECTIVE_RADIUS'): BEGIN ;reff_rad
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
                                ;        IF(ivar gt 4 and data.data.Cloud_Top_Altitude._data[idata] lt 0)THEN line_print=STRING(-999,FORMAT=formats[ivar])
                                print_line=print_line+', '+ line_print;

                        ENDFOR
                        IF(add_cirrus_mask[idate])THEN $
                        IF(cirrus_file_check eq 1) THEN print_line=print_line+', '+STRING(data_cirrus.CIRRUS_MASK._data[idata],FORMAT='(I4)') ELSE print_line=print_line+', -999'

                        IF KEYWORD_SET(switch_print)THEN print,idata,print_line
                        IF ~KEYWORD_SET(switch_no_save)THEN  printF,lun, print_line
                        ; if(MIN(i999) eq 0 and data.data.Cloud_Bow_Droplet_Effective_Radius._data[idata] lt 0)THEN stop


                ENDFOR

        ENDFOR

        IF ~KEYWORD_SET(switch_no_save)THEN FREE_LUN,LUN
ENDFOR


;stop





end
