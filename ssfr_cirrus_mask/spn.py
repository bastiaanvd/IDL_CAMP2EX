"""
Created on Wed Aug 28 15:22:05 2019

Read h5 file of SSFR/SPN field data and analyze

@author: Sebastian Schmidt
Contributors: Snorre Stamnes.
"""

import h5py
import numpy as np
import matplotlib.pyplot as plt
import glob
import os

wl = 860      # desired wl to use from SPN
#ur = [26,30]  # utc plot range

"""
Download all the CAMP2Ex the data from here:
https://drive.google.com/open?id=1YaYqb6bgM6wtfOBWSiEaEimOKNkhWJNJ
"""

#file = '../SSFR_20190921_IWG.h5'
#all_files = ['SSFR_20190921_IWG.h5']

all_files = sorted(glob.glob("./SSFR_*_IWG.h5"))
print "all_files =", all_files

for file in all_files:

	print "file =", file
	filename = os.path.basename(file)
	date_str = filename[5:5+8]
	print "date_str =", date_str
	h5   = h5py.File(file , 'r')
	
	utc  = h5['tmhr'][...]
	alt  = h5['alt'][...]
	lat  = h5['lat'][...]
	lon  = h5['lon'][...]
	zen  = h5['zen_flux'][...]
	nad  = h5['nad_flux'][...]
	zwl  = h5['zen_wvl'][...]
	nwl  = h5['nad_wvl'][...]
	utcs = h5['spns_tmhr'][...]
	zens = h5['spns_tot_flux'][...]
	zend = h5['spns_dif_flux'][...]
	zwls = h5['spns_wvl'][...]
	sza  = h5['sza'][...]
	lds  = np.argmin(np.abs(zwls-wl))
	h5.close()

	# look for the requested SPN wavelength (e.g. 860)
	wli       = np.argmin(np.abs(zwls - wl))
	#print "spns_wvl =", zwls
	#print "wli =", wli
	print "zwls[wli] (wavelength used) =", zwls[wli]
	# calculate direct-beam transmittance (equivalent to sunphotometer)
	Tdir      = (zens[:,wli] - zend[:,wli])
	flt       = np.where(zens[:,wli] > 0.01)
	Tdir[flt] = Tdir[flt]/zens[flt,wli]
	
	# filter data
	flt  = np.where((Tdir < 1) & (Tdir > 0))
	Tdir = Tdir[flt]
	utcs = utcs[flt]
	mus  = np.interp(utcs,utc,np.cos(np.pi/180.*sza))
	
	fig,ax = plt.subplots(1,2,figsize=(12,7))
	ax[0].plot(utc,np.cos(np.pi/180.*sza),'r-',label='$\mu=cos(SZA)$')
	ax[0].plot(utcs,Tdir,'k.',label='T (direct-beam transmittance)')
	ax[0].set_xlabel('UTC')
	ax[0].set_ylabel('$\mu$ and T')
	#ax[0].set_xlim(ur)
	ax[0].legend()
	ax01 = ax[0].twinx()
	ax01.plot(utc,alt,'b-',label='aircraft altitude [m]')
	ax01.set_ylabel('altitude [m]')
	ax01.legend()
	
	# Only report flag for Tdir>0.2:
	flt = np.where(Tdir>0.2)
	#flag = -mus*np.log(Tdir)
	optical_depth = -mus*np.log(Tdir)

	#cirrus_mask = np.where(optical_depth < 0.04)
	cirrus_mask = (optical_depth < 0.04) & (Tdir > 0.2)
	print "len(optical_depth) =", len(optical_depth)
	print "len(cirrus_mask)   =", len(cirrus_mask)
	print "len(utcs)          =", len(utcs)

	ax[1].plot(utcs[flt], optical_depth[flt],'k.',label='Proxy optical depth')
	ax[1].plot(utcs[flt], cirrus_mask[flt],'r',label='Ci mask: 1=clear, 0=cirrus/high OD')
	#ax[1].set_xlim(ur)
	ax[1].set_xlabel('UTC')
	ax[1].set_ylabel('Proxy OD @ 860 nm and Ci flag')
	ax[1].legend()
	fig.tight_layout()
	plt.show(block=False)
	my_file = 'fig-SPN-' + date_str + '-OpticalDepth860nm' + '.pdf'
	print "saving to file", my_file
	plt.savefig(my_file, bbox_inches='tight')
	#np.savetxt('SPN-' + date_str + '-time.txt',utcs)
	#np.savetxt('SPN-' + date_str + '-cirrus-mask.txt',cirrus_mask)
	h5_file_name = 'SPN-' + date_str + '-cirrus-mask.h5'
	with h5py.File(h5_file_name, 'w') as f:
		dset = f.create_dataset("time", data=utcs)
		dset = f.create_dataset("cirrus_mask", data=cirrus_mask)
		dset = f.create_dataset("T_direct_beam_transmittance_860", data=Tdir)
		dset = f.create_dataset("SPN_proxy_optical_depth_860", data=optical_depth)
