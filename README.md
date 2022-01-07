# Simlink
"simullink" type package for loop stability simulations - mostly geared at MAVIS

## Goal

Investigate the overall MAVIS loop stability given the complex control scheme that we have establish for the control of TT, focus and associated offloads.

## Package description

The package is made of two main files:

1. `simlink.i`: This is the main, generic file containing generic package functions. Its main function is loop(). It also contains structure definition and other utilitary functions, including plot functions.
2. `parfile`, in this case `mavis.par`: This is the system specific file that contains the system definition (in `init_nodes()`), but also the specific definition of some nodes actions, event functions (to allow for running scenario like changing gains, conditions, etc), prerun and postrun functions, etc. 

More to come. Also add sections:

## Examples

## Development plan



