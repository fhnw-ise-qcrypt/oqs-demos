#!/usr/bin/env python3
import parse_kemsig as ks
import os
import argparse
import numpy as np
import re
from matplotlib import pyplot as plt
from matplotlib import rcParams

# General plot configuration
rcParams.update({'figure.autolayout': True})
fontSize = {'title': 22,
            'ticklabels': 18,
            'axeslabels': 18,
            'annotations': 16,
            'legend': 18}


def sort_nicely(l):
    """ Sort the given list in the way that humans expect.
    """
    def convert(text): return int(text) if text.isdigit() else text
    def alphanum_key(key): return [convert(c)
                                   for c in re.split('([0-9]+)', key)]
    l.sort(key=alphanum_key)
    return l


# Setup argument parser
parser = argparse.ArgumentParser(description="Plots benchmarking results")
parser.add_argument('--dir', '-d', action='store', dest='dir', required=True,
                    help='Directory with .csv files that should be plotted.')
parser.add_argument('--percentiles', '-p', action='store', dest='percentiles', required=False,
                    default='50,95', help='The percentiles that should be calculated and plotted. Supply as comma separated list')
parser.add_argument('--title', '-t', action='store', dest='plotTitle', required=False,
                    help='Optional plot title')
parser.add_argument('--round', '-r', action='store', dest='precision', required=False, default=2,
                    help='How many decimals the numbers should be rounded to')

args = parser.parse_args()

# Parse, sort and clean up list for percentiles and other settings
calcPercentiles = list(
    sorted(set([int(v) for v in str(args.percentiles).split(',')])))
annotationPrecision = int(args.precision)
superTitle = args.plotTitle + '\n' if args.plotTitle else ''

# Get Kem and Sig data
kemsigs = []
path = os.path.abspath(args.dir)
for filename in sort_nicely(os.listdir(path)):
    if filename.endswith('.csv'):
        kemsigs.append(ks.KemSigPair(os.path.join(
            path, filename), calcPercentiles))

if not kemsigs:
    print("### [FAIL] ### No valid files found. Aborting...")
    exit(1)

for i, each in enumerate(kemsigs):
    if each.sig == 'ssh-ed25519' or each.sig == 'ecdsa-sha2-nistp*':
        kemsigs.insert(0, kemsigs.pop(i))

# Define some useful functions


def labelBars(rectsBot, rectsTop):
    """Attaches a text labels above each bar in a stacked bar plot displaying its height. *rectsBot* is the lower bars, *rectsTop* is the higher bars."""
    for bot, top in zip(rectsBot, rectsTop):
        heightBot = np.round(bot.get_height(), annotationPrecision)
        heightTop = np.round(top.get_height() + heightBot, annotationPrecision)
        ax.annotate('{}'.format(heightBot),
                    xy=(bot.get_x() + bot.get_width() / 2, heightBot),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=fontSize['annotations'])
        ax.annotate('{}'.format(heightTop),
                    xy=(top.get_x() + top.get_width() / 2, heightTop),
                    xytext=(0, 3),  # 3 points vertical offset
                    textcoords="offset points",
                    ha='center', va='bottom',
                    fontsize=fontSize['annotations'])


def percentileString(calcPercentiles):
    percStr = ''
    if len(calcPercentiles) == 1:
        percStr = '{}th percentile'.format(calcPercentiles[0])
    else:
        for i, p in enumerate(calcPercentiles, 1):
            if i == len(calcPercentiles):
                percStr += 'and {}th percentile'.format(p)
            elif i == len(calcPercentiles) - 1:
                percStr += '{}th '.format(p)
            else:
                percStr += '{}th, '.format(p)
    return percStr


### Print stuff ###
# Print RTT information
print('Average Rount-Trip-Time with ' + superTitle[:-1] + ': ' +
      str(np.round(np.average([v.averages['rtt'] for v in kemsigs]), 4)))
print('Median Rount-Trip-Time with ' + superTitle[:-1] + ': ' +
      str(np.round(np.median([v.medians['rtt'] for v in kemsigs]), 4)))

### Plot stuff ###
# Get data
numBars = len(calcPercentiles)
kexPercentiles = [v.percentiles['kex'] for v in kemsigs]
authPercentiles = [v.percentiles['auth'] for v in kemsigs]

maxWidth = 1.0
totalWidth = maxWidth * numBars / (numBars + 1)
barWidth = totalWidth / numBars
offset = (barWidth - totalWidth) / 2

xKexData = []
subIndieces = []
for i, l in enumerate(kexPercentiles, 1):
    for j, v in enumerate(l):
        xKexData.append(v)
        subIndieces.append(i + offset + j * barWidth)

xAuthData = []
for l in authPercentiles:
    for v in l:
        xAuthData.append(v)

# Plot and configure plot
indieces = np.arange(1, len(kemsigs) + 1)
f0 = plt.figure()
ax = plt.axes()
plt.grid(True, which='major', linestyle=":")
rectsKex = ax.bar(subIndieces, xKexData, barWidth * 0.95)
rectsAuth = ax.bar(subIndieces, xAuthData, barWidth * 0.95, bottom=xKexData)
labelBars(rectsKex, rectsAuth)
ax.set_ylabel('Handshake duration (sec)', fontsize=fontSize['axeslabels'])
ax.set_title(superTitle +
             'Handshake time by algorithm, split into key exchange and authentication' + '\n' + percentileString(calcPercentiles), fontsize=fontSize['title'])
plt.yticks(fontsize=fontSize['ticklabels'])
plt.xticks(indieces, [each.__str__()
                      for each in kemsigs], rotation=30, ha="right", fontsize=fontSize['ticklabels'])
plt.legend(['Key Exchange', 'Authentication'], fontsize=fontSize['legend'])

plt.show()
