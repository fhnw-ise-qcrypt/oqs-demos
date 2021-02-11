#!/usr/bin/env python3
import csv
import numpy as np
import re


class KemSigData:
    loop = []
    rtt = []
    startNo = []
    startT = []
    newKeysNo = []
    newKeysT = []
    endNo = []
    endT = []
    kexT = []
    authT = []
    hsT = []

    def __init__(self, file):
        with open(file, 'r') as f:
            d = csv.reader(f)  # read all rows
            d = zip(*d)  # transpose --> we've got columns now
            d = list(d)
            self.loop = [float(v) for v in d[0][1:]]
            self.rtt = [float(v) for v in d[1][1:]]
            self.startNo = [float(v) for v in d[2][1:]]
            self.startT = [float(v) for v in d[3][1:]]
            self.newKeysNo = [float(v) for v in d[4][1:]]
            self.newKeysT = [float(v) for v in d[5][1:]]
            self.endNo = [float(v) for v in d[6][1:]]
            self.endT = [float(v) for v in d[7][1:]]
            self.kexT = [float(v) for v in d[8][1:]]
            self.authT = [float(v) for v in d[9][1:]]
            self.hsT = [float(v) for v in d[10][1:]]

        self.timeData = {'rtt': self.rtt, 'kex': self.kexT,
                         'auth': self.authT, 'handshake': self.hsT}


class KemSigPair:

    def __init__(self, file, percentiles2calc=[50, 90]):
        self.percentiles2calc = percentiles2calc
        self.kem, self.sig = re.sub(
            r'^.*/', '', re.sub(r'\.csv$', '', file)).split('_')
        self.file = file
        self.data = KemSigData(file)
        self.calcSpecs()

    def __str__(self):
        return self.kem + ' + ' + self.sig

    def calcSpecs(self):
        self.averages = {}
        self.percentiles = {}
        for k, v in self.data.timeData.items():
            if k == 'rtt' or k == 'kex' or k == 'auth' or k == 'handshake':
                self.averages[k] = np.average(v)
                self.percentiles[k] = [float(each) for each in np.percentile(
                    v, self.percentiles2calc).tolist()]
