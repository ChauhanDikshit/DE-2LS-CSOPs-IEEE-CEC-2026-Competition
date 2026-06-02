import numpy as np
for i,D in enumerate([30]):
    for f in range(1,29):
        filename = f"CL-SRDE_F{f}_D{D}.txt"
        X = np.loadtxt(filename)
        np.savetxt(filename,X.T,fmt='%.18G')