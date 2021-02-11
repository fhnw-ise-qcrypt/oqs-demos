#!/usr/bin/env python3
from matplotlib import pyplot as plt
import argparse
import os

import parse_kemsig as ks

parser = argparse.ArgumentParser(description="Plots benchmarking results")
parser.add_argument('--dir', '-d', action='store', dest='dir', required=True,
                    help='Directory with .csv files that should be plotted.')
args = parser.parse_args()

print(os.path.dirname(os.path.abspath(__file__)))
# os.path.
kemsigs = []
path = os.path.abspath(args.dir)
for filename in os.listdir(path):
    if filename.endswith('.csv'):
        kemsigs.append(ks.KemSigPair(os.path.join(path, filename)))

if not kemsigs:
    print("### [FAIL] ### No valid files found. Aborting...")
    exit(1)

for i, each in enumerate(kemsigs):
    print('Found and parsed data for: ' + str(each))
    if each.sig == 'ssh-ed25519' or each.sig == 'ecdsa-sha2-nistp*':
        kemsigs.insert(0, kemsigs.pop(i))


# f0 = plt.figure(0)

# xelements = [kem, sig, kem + ' + ' + sig]
# xelements = ['90th', '50th']
# ind = np.arange(len(xelements))

# ax = plt.axes()

# p1 = ax.bar(ind, [ksp.percentiles['hs_t']['90th'],
#                   percentiles['hs_t']['50th']])
# p1.xticks(ind, xelements)

# plt.show()
