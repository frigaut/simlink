#!/usr/bin/env python
import PySimpleGUI as sg
import sys

# print("hello, mavis.py here")
sg.theme("DarkBlue3")
sg.set_options(font=("Roboto", 14))

def py2yo(msg):
   # sends string command to yorick's eval
   sys.stdout.write(msg+'\n')
   sys.stdout.flush()
   

# Define the window's contents
layout = [[sg.Text("Simlink control panel")],
          [sg.Text("NGS loop",size=(15,1)),
             sg.Text("gain:",size=(4,1)), 
             sg.Input(key='-ngsloopgain-',size=(5,1)),
             sg.Button('Open',key='ngsloopopen'),
             sg.Button('Close',key='ngsloopclose')],
          [sg.Text("LGS loop",size=(15,1)),
             sg.Text("gain:",size=(4,1),key=''), 
             sg.Input(key='-lgsloopgain-',size=(5,1)),
             sg.Button('Open',key='lgsloopopen'),
             sg.Button('Close',key='lgsloopclose')],
          [sg.Text("FSM loop",size=(15,1)),
             sg.Text("gain:",size=(4,1),key=''), 
             sg.Input(key='-fsmloopgain-',size=(5,1)),
             sg.Button('Open',key='fsmloopopen'),
             sg.Button('Close',key='fsmloopclose')],
          [sg.Text("DSM offload",size=(15,1)),
             sg.Text("gain:",size=(4,1),key=''), 
             sg.Input(key='-dsmoffloadgain-',size=(5,1)),
             sg.Button('Open',key='dsmoffloadopen'),
             sg.Button('Close',key='dsmoffloadclose')],
          [sg.Text("FSM ➜ FM",size=(15,1)),
             sg.Text("gain:",size=(4,1),key=''), 
             sg.Input(key='-fsmoffloadgain-',size=(5,1)),
             sg.Button('Open',key='fsmoffloadopen'),
             sg.Button('Close',key='fsmoffloadclose')],
          [sg.Text("NGS focus offload",size=(15,1)),
             sg.Text("gain:",size=(4,1),key=''), 
             sg.Input(key='-ngsfocusoffloadgain-',size=(5,1)),
             sg.Button('Open',key='ngsfocusoffloadopen'),
             sg.Button('Close',key='ngsfocusoffloadclose')],
          [sg.Text("All loops and offloads",size=(19,1)),
             sg.Button('Open',key='allloopsopen'),
             sg.Button('Close',key='allloopsclose'),
             sg.Button('Reset',key='allloopsreset')],
          [sg.Text("LGS1"),sg.Button('🡄',key='lgs1left'), sg.Input(key='-offset-',size=(5,1)), sg.Button("🡆",key='lgs1right')],
          [sg.Text("Telmount"),sg.Button('',key='telleft'),sg.Button('',key='teldown'),sg.Button('',key='telup'),sg.Button('',key='telright'),sg.Input(key='-teloffset-',size=(5,1)), sg.Button("🡆",key='lgs1right')],
          [sg.Button('Quit')]]

# Create the window
window = sg.Window('Window Title', layout, finalize=True)
window['-ngsloopgain-'].bind("<Return>", "_Enter")
window['-lgsloopgain-'].bind("<Return>", "_Enter")
window['-fsmloopgain-'].bind("<Return>", "_Enter")
window['-dsmoffloadgain-'].bind("<Return>", "_Enter")
window['-fsmoffloadgain-'].bind("<Return>", "_Enter")
window['-ngsfocusoffloadgain-'].bind("<Return>", "_Enter")

# Display and interact with the Window using an Event Loop
while True:
    event, values = window.read()
    # py2yo('%s' % event)
    if event == 'ngsloopopen':
        py2yo('pyk_set gain_ngs_on 0')
        # window['-ngsloopgain-'].update('-0.3')
    if event == 'ngsloopclose':
        py2yo('pyk_set gain_ngs_on 1')
    if event == 'lgsloopopen':
        py2yo('pyk_set gain_lgs_foc_on 0')
    if event == 'lgsloopclose':
        py2yo('pyk_set gain_lgs_foc_on 1')
    if event == 'fsmloopopen':
        py2yo('pyk_set gain_lgs_fsm_on 0')
    if event == 'fsmloopclose':
        py2yo('pyk_set gain_lgs_fsm_on 1')
    if event == 'dsmoffloadopen':
        py2yo('pyk_set gain_dsm_offload_on 0')
    if event == 'dsmoffloadclose':
        py2yo('pyk_set gain_dsm_offload_on 1')
    if event == 'fsmoffloadopen':
        py2yo('pyk_set gain_fsm_offload_on 0')
    if event == 'fsmoffloadclose':
        py2yo('pyk_set gain_fsm_offload_on 1')
    if event == 'ngsfocusoffloadopen':
        py2yo('pyk_set gain_ngs_focus_offload_on 0')
    if event == 'ngsfocusoffloadclose':
        py2yo('pyk_set gain_ngs_focus_offload_on 1')
    if event == 'allloopsopen':
        py2yo('pyk_set gain_ngs_on 0')
        py2yo('pyk_set gain_lgs_foc_on 0')
        py2yo('pyk_set gain_lgs_fsm_on 0')
        py2yo('pyk_set gain_dsm_offload_on 0')
        py2yo('pyk_set gain_fsm_offload_on 0')
        py2yo('pyk_set gain_ngs_focus_offload_on 0')
    if event == 'allloopsclose':
        py2yo('pyk_set gain_ngs_on 1')
        py2yo('pyk_set gain_lgs_foc_on 1')
        py2yo('pyk_set gain_lgs_fsm_on 1')
        py2yo('pyk_set gain_dsm_offload_on 1')
        py2yo('pyk_set gain_fsm_offload_on 1')
        py2yo('pyk_set gain_ngs_focus_offload_on 1')
    if event == 'allloopsreset':
        py2yo('allloopsreset')
    if event == '-ngsloopgain-_Enter':
        py2yo('pyk_set gain_ngs %s' % values['-ngsloopgain-'])
    if event == '-lgsloopgain-_Enter':
        py2yo('pyk_set gain_lgs_foc %s' % values['-lgsloopgain-'])
    if event == '-fsmloopgain-_Enter':
        py2yo('pyk_set gain_lgs_fsm %s' % values['-fsmloopgain-'])
    if event == '-dsmoffloadgain-_Enter':
        py2yo('pyk_set gain_dsm_offload %s' % values['-dsmoffloadgain-'])
    if event == '-fsmoffloadgain-_Enter':
        py2yo('pyk_set gain_fsm_offload %s' % values['-fsmoffloadgain-'])
    if event == '-ngsfocusoffloadgain-_Enter':
        py2yo('pyk_set gain_ngs_focus_offload %s' % values['-ngsfocusoffloadgain-'])
    if event == 'telleft':
        py2yo('teloffset -2 0')
    if event == 'telright':
        py2yo('teloffset +2 0')
    if event == 'teldown':
        py2yo('teloffset 0 -2')
    if event == 'telup':
        py2yo('teloffset 0 +2')
    if event == 'lgs1left':
        py2yo('lgs_offset 1 -2')
    if event == 'lgs1right':
        py2yo('lgs_offset 1 2')
    # See if user wants to quit or window was closed
    if event == sg.WINDOW_CLOSED or event == 'Quit':
        break
# Finish up by removing from the screen
window.close()
