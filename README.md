# Repository name

*eeg-asd-n400*

# Introduction

This repository contains MATLAB functions and scripts for preprocessing of EEG data and N400 amplitude extraction in the context of the paper title *paper title* (*link to paper*).

The preprocessing is split it two parts, where *[asd_continuous](/asd_continuous.m)* imports and preprocesses the continuous EEG data, and *[asd_epoch_rel_unr](/asd_epoch_rel_unr.m)* and *[asd_epoch_sym_eq_unr](asd_epoch_sym_eq_unr.m)* extracts epochs, and identify and reject bad epochs.

Finally, N400 measurements - here defined as the mean amplitude between 300 ms to 500 ms post-stimulus - are extracted using *[asd_extractN400](/asd_extractN400.m)*.