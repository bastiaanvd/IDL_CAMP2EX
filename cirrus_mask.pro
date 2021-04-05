; NAME:
;   Cirrus_mask
;
; PURPOSE:
;   Finds colocations between SPN cirrus mask and RSP L1C
;   Saves cirrus files in format compatible to RSP L1C
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
;   - find match in time
;   - output file
;
; :Usage:
;   To run: cirrus_mask,settings_file
;   Settings_file.csv contains paths and dates to process 
;   Settings_file.csv also contains output folder, etc.
;   Settings_file.csv also contains path to SPN data
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
;     created: <<5 April 2021
;---------------------------------
;switches

pro Cirrus_mask,settings_file



settings=read_csv(settings_file,N_TABLE_HEADER=1,TABLE_HEADER=settings_header)
dates=STRCOMPRESS(settings.field1,/REMOVE_ALL)
path_rsp=STRCOMPRESS(settings.field2,/REMOVE_ALL)
prefix_folder=STRCOMPRESS(settings.field3,/REMOVE_ALL)
end_folder=STRCOMPRESS(settings.field4,/REMOVE_ALL)
prefix_file=STRCOMPRESS(settings.field5,/REMOVE_ALL)
path_out=STRCOMPRESS(settings.field6,/REMOVE_ALL)
prefix_file_out=STRCOMPRESS(settings.field7,/REMOVE_ALL)
version=STRCOMPRESS(settings.field8,/REMOVE_ALL)
path_SPN=STRCOMPRESS(settings.field9[0],/REMOVE_ALL)

parameters=['T_DIRECT_BEAM_TRANSMITTANCE_860','SPN_PROXY_OPTICAL_DEPTH_860','CIRRUS_MASK']
Long_names=['Direct beam transmittance derived from SPN at 860 nm','Optical depth above aircraft derived from transmittance using Lambert-Beer law','Cirrus mask: 0 where COD>0.04 + transmittance is <0.2; 1 elsewhere']
Fill_value=[-999,-999,-999]

ndates=n_elements(dates)
end_file='.h5'

for idate = 0, ndates-1 do begin
    folder=prefix_folder[idate]+dates[idate]+end_folder[idate]
    files_rsp=FILE_SEARCH(path_RSP[idate]+folder+prefix_file[idate]+'*'+end_file,COUNT=nfiles)
    print,dates[idate],' nfiles:',nfiles
    file_spn='SPN-'+dates[idate]+'-cirrus-mask.h5'
    check_spn=FILE_SEARCH(path_SPN+file_spn,COUNT=nfiles_spn)   
        
    IF(nfiles_spn eq 1)THEN data_spn=h5_PARSE(path_SPN+file_spn,/READ_DATA) else BEGIN
        print,'No SPN data for this date'
        CONTINUE
    ENDELSE 
    
    for ifile = 0, nfiles-1 do begin
        data_rsp=h5_PARSE(files_rsp[ifile],/READ_DATA)
        times_hr=data_rsp.data.PRODUCT_TIME_SECONDS._data/86400.000*24.
        ntime=n_elements(times_hr)
        COD_spn=MAKE_ARRAY(ntime,/FLOAT,VALUE=-999)
        CIRRUS_MASK_spn=MAKE_ARRAY(ntime,/INTEGER,VALUE=-999)
        trans_spn=MAKE_ARRAY(ntime,/FLOAT,VALUE=-999)
        
        imatch=FLTARR(ntime)
        FOR itime=0,ntime-1 DO BEGIN
            find_match=MIN(ABS(times_hr[itime]-data_spn.time._data),imatch1)
      
            IF(find_match le 1.5/3600.)THEN BEGIN
            imatch[itime]=imatch1
            COD_spn[itime]=data_spn.SPN_PROXY_OPTICAL_DEPTH_860._data[imatch1]
            CIRRUS_MASK_spn[itime]=data_spn.CIRRUS_MASK._data[imatch1]
            trans_spn[itime]=data_spn.T_DIRECT_BEAM_TRANSMITTANCE_860._data[imatch1]
            
            ENDIF
            ;print,times_hr[itime] ,   COD_spn[itime],CIRRUS_MASK_spn[itime],trans_spn[itime],find_match

        ENDFOR

        data={T_DIRECT_BEAM_TRANSMITTANCE_860:trans_spn,SPN_PROXY_OPTICAL_DEPTH_860:COD_spn,CIRRUS_MASK:CIRRUS_MASK_spn}
        file_end1=STRMID(files_rsp[ifile],40,41,/REVERSE_OFFSET)
        parts=STRSPLIT(file_end1,'T',/EXTRACT)
        parts2=STRSPLIT(parts[1],'Z',/EXTRACT)
        file_end=parts[0]+parts2[0]+version[idate]+'.h5'
;        stop

        fid = H5F_CREATE(path_out[idate]+prefix_file_out[idate]+file_end)
        dataspace_id_attr = H5S_CREATE_SIMPLE(1)
        
        ;Global attributes
        attribute_name='File created'
        attribute=SYSTIME()
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 
        
        attribute_name='Description'
        attribute='Above aircraft observations by SPN sampled on RSP nadir footprint time (Product_time). If no SPN data within 1.5 seconds of RSP Product_time is available, fill values are used.  Cirrus mask can be readily applied to RSP LV1C and L2 data'
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 

        attribute_name='Experiment'
        attribute=data_rsp.EXPERIMENT._data
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 


        attribute_name='PI RSP'
        attribute='Bastiaan van Diedenhoven'
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 
        
        attribute_name='PI SPN'
        attribute='K. Sebastian Schmidt'
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 

        attribute_name='RSP LV1C file name'
        attribute=FILE_BASENAME(files_rsp[ifile])
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 

        attribute_name='SPN cirrus file name'
        attribute=file_spn
        datatype_id_attr = H5T_IDL_CREATE(attribute)
        attr_id = H5A_CREATE(fid,attribute_name,datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,attribute
        H5A_CLOSE,attr_id 



        TAG_NAMES_data=TAG_NAMES(data)
        for idata=n_tags(data)-1,0,-1 DO BEGIN
            datatype_id = H5T_IDL_CREATE(data.(idata))
            dataspace_id = H5S_CREATE_SIMPLE(size(data.(idata),/DIMENSIONS))
            dataset_id = H5D_CREATE(fid,TAG_NAMES_data[idata],datatype_id,dataspace_id)
            H5D_WRITE,dataset_id,data.(idata)

            
            datatype_id_attr = H5T_IDL_CREATE(long_names[idata])
            attr_id = H5A_CREATE(dataset_id,'Long_name',datatype_id_attr,dataspace_id_attr)
            H5A_WRITE,attr_id,long_names[idata]
            H5A_CLOSE,attr_id             

            datatype_id_attr = H5T_IDL_CREATE(Fill_value[idata])
            attr_id = H5A_CREATE(dataset_id,'Fill_value',datatype_id_attr,dataspace_id_attr)
            H5A_WRITE,attr_id,Fill_value[idata]
            H5A_CLOSE,attr_id 
            

            H5D_CLOSE,dataset_id
            H5S_CLOSE,dataspace_id
            H5T_CLOSE,datatype_id
        ENDFOR

        data_write=data_rsp.data.PRODUCT_TIME_SECONDS._data
        datatype_id = H5T_IDL_CREATE(data_write)
        dataspace_id = H5S_CREATE_SIMPLE(size(data_write,/DIMENSIONS))
        dataset_id = H5D_CREATE(fid,'PRODUCT_TIME_SECONDS',datatype_id,dataspace_id)
        H5D_WRITE,dataset_id,data_write

        long_name=data_rsp.data.PRODUCT_TIME_SECONDS.long_name._data
        datatype_id_attr = H5T_IDL_CREATE(long_name)
        attr_id = H5A_CREATE(dataset_id,'Long_name',datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,long_name
        H5A_CLOSE,attr_id  
        H5D_CLOSE,dataset_id
        H5S_CLOSE,dataspace_id
        H5T_CLOSE,datatype_id
   
        data_write=data_rsp.geometry.Collocated_latitude._data[*,0]
        datatype_id = H5T_IDL_CREATE(data_write)
        dataspace_id = H5S_CREATE_SIMPLE(size(data_write,/DIMENSIONS))
        dataset_id = H5D_CREATE(fid,'Collocated_latitude',datatype_id,dataspace_id)
        H5D_WRITE,dataset_id,data_write

        long_name=data_rsp.geometry.Collocated_latitude.long_name._data
        datatype_id_attr = H5T_IDL_CREATE(long_name)
        attr_id = H5A_CREATE(dataset_id,'Long_name',datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,long_name
        H5A_CLOSE,attr_id  
        H5D_CLOSE,dataset_id
        H5S_CLOSE,dataspace_id
        H5T_CLOSE,datatype_id
   
        data_write=data_rsp.geometry.Collocated_longitude._data[*,0]
        datatype_id = H5T_IDL_CREATE(data_write)
        dataspace_id = H5S_CREATE_SIMPLE(size(data_write,/DIMENSIONS))
        dataset_id = H5D_CREATE(fid,'Collocated_longitude',datatype_id,dataspace_id)
        H5D_WRITE,dataset_id,data_write

        long_name=data_rsp.geometry.Collocated_longitude.long_name._data
        datatype_id_attr = H5T_IDL_CREATE(long_name)
        attr_id = H5A_CREATE(dataset_id,'Long_name',datatype_id_attr,dataspace_id_attr)
        H5A_WRITE,attr_id,long_name
        H5A_CLOSE,attr_id  
        H5D_CLOSE,dataset_id
        H5S_CLOSE,dataspace_id
        H5T_CLOSE,datatype_id



        H5S_CLOSE,dataspace_id_attr
        H5F_CLOSE,fid
        print,file_end
        ;stop
    endfor
endfor



end
