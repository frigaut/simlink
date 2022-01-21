/*******  simlink.i package functions **********
Invoke with, e.g.:
loop,"mavis-simple.par",500,init=1
to stop: either wrap_series is set to 0, in case it'll stop by itself
or one can do:
loop,end=1

Now with the ability to inject command while loop is running 
(>v1.4), those are useful commands:
NGS offset:
nodes(id_match("ngs_wfs")).offset = [0.,2.0];
LGS motion:
nodes(id_match("lgs1")).offset += [0.,3.0];
telmount jumping:
nodes(id_match("telmount")).ttpos -= [0.,-3.0]
jump in lgs focus stage:
nodes(id_match("lgs_focus_stage")).focpos+=0.2
Defocus NGS wrt LGS:
nodes(id_match("ngs_focus_stage")).focpos+=0.2
Defocus science objective:
nodes(id_match("sci_objective")).focpos+=0.2
*********************************************/

simlink_version = 1.7;
usercol = torgb([0xfb4934,0xb8bb26,0x83a598,0xfe8019,0xb16286,0x8ec07c,0xfabd2f]);
usercol = torgb([0xff5555,0x50fa7b,0xf1fa8c,0xbd93f9,0xff79c6,0x8be9fd,0xff6188,0xa9dc76,0xffd866,0xfc9867,0xab9df2,0x78dce8,0xffffff]);
usercol = torgb([0xff6188,0xa9dc76,0xffd866,0xfc9867,0xab9df2,0x78dce8,0xffffff,0xff5555,0x50fa7b,0xf1fa8c,0xbd93f9,0xff79c6,0x8be9fd]);
pldefault,edges=1,ecolor=[128,128,128];

ncols = numberof(usercol);
pldefault,dpi=120; //120
use_sway = 1;

// Structure declaration
struct node {
  string name; // name of the node
  int path; // sum of path to which the node pertains, for instance
  // 001: science = 1, 010: ngs = 2, 100: lgs = 4
  // e.g. path=7 ➜ all of science, ngs, lgs
  // path=6 ➜ science and lgs, etc, can add ad libitum other e.g. LGS
  float offset(2);  // offset of the node (useful for off-axis things)
  float foc_offset; // offset of the node (useful for off-axis things)
  float limit;     // limit threshold for ttpos (e.g. 3")
  float go_to(2);   // set point for mechanism
  float pid(3);     // PID controller parameters for mechanism
  float foc_limits; // + and - limit threshold for focus
  string action;    // name of a callback function to effect an action
  string action_on; // for use in generic function allow to pass which node the action has to apply on
  string type;      // "mir", "foc", nothing or "fp" (focal plane)
  long plot(2);     // window and plsys in which this node has to be plot. plsys=0 means no plot.
  float ts(2);      // TT perturbation time series parameters: stdev,knee
  float fs(2);      // Focus perturbation time series parameters: stdev,knee
  long delay;       // "Loop" delay in frames for this node. 0 = no delay
  float freqratio;  // ratio of control rate for this node wrt to base frequency. e.g. 10 = freq/10
  // INTERNAL PARAMETERS (not intended to be messed with)
  int id;           // assigned by init_nodes()
  float ttpos(2);   // current TT position of node
  float focpos;     // current focus position of the node
  pointer tt_turb_series;  // pointer to TT time series (perturbation)
  pointer foc_turb_series; // pointer to focus time series (perturbation)
  pointer pos_series;  // pointer to 2xNit array to receive TT positions versus time. for rms etc 
  pointer poff_series; // pointer to 2xNit array to receive TT offsets versus time. for rms etc 
  pointer foc_series;  // pointer to Nit array to receive focus versus time. for rms etc 
  pointer foff_series; // pointer to Nit array to receive focus offsets versus time. for rms etc 
};

// Functions definitions
func init_windows(nwin)
{
  extern xglabs;
  off = -0.05;
  xglabs = 0.65+off;
  for (n=1;n<=nwin;n++) {
    winkill,n-1;
    if (use_sway) {
      if ((n-1)==0) {
        system,"swaymsg for_window [class=\"Gist\"] floating disable";
        system,"swaymsg splitv;";
      }
      if ((n-1)==1) {
        system,"swaymsg splith;";
      }
    }
    // pause,50;
    plsplit,1,1,win=n-1,vp=[0.22+off,0.63+off,0.44,0.85];
  }
}


func id_match(name)
/* DOCUMENT id_match(name)
   Return id of matching path name, trigger error if no match
*/
{
  if (numberof(where(nodes.name==name))==0) \
    error,swrite(format="No match for id %s\n",name);
  return nodes.id(where(nodes.name==name));
}

func path_match(path1,path2)
/* DOCUMENT path_match(path1,path2)
   Matches two paths, 1 if the same, 0 if not
*/
{ 
  return (path1&path2); 
}

func uniqwid(wid)
/* DOCUMENT uniqwid(wid)
   Find unique WID number in list of wid
*/
{
  // vector of all requested window ID
  wid = wid(sort(wid));
  uwid = _(wid(where(wid(dif))),wid(0));
  return uwid;
}

func propagate_to(id)
/* DOCUMENT propagate_to(id)
   Propagate signal (TT or focus) to said node id
   Usually used to propagate to focal planes (nodes.type="fp")
*/
{
  extern nodes;
  path = nodes(id).path;
  // what nodes are in this path?
  w = where(path_match(path,nodes.path))(:-1);
  nodes(id).ttpos = nodes(w).ttpos(,sum);
  nodes(id).focpos = sum(nodes(w).focpos);
}


func loop(parfile,nit,init=,end=)
/* DOCUMENT loop(parfile,nit)
   Main function. 
   Use loop,parfile,init=1 to start
   Use loop,end=1 to stop
   Will start over at nit=1 if wrap_series=1, otherwise exit when nit is reached.
   Loop over the whole system, iteration by iteration.
   Exits between iterations to be able to input things at main prompt
   Calls itself with after()
   Call outside event function to effect things to the system 
     at particular iterations #
   Applies special callbacks (actions) for the nodes for which they 
     are required/defined.
   Plots and accumulate statistics. Final printouts.
*/
{
  extern nodes,delay_start;
  extern mirlimit,nn,NIT,itv;

  if (init) {
    // init things
    // The parfile is where all the system is defined, as well as
    // callback functions (actions)
    include,parfile,1;
    // possibility to run a prerun function (e.g. to record a movie)
    if (prerun!=[]) status = prerun();
    if (animate_plots) for (i=0;i<=1;i++) { window,i; animate,1;}
    mirlimit = 0.; // Just for graphics
    // used to slow or pause display + resume with initial value of delay
    delay_start = delay; 
    if (itv!=[]) itv *= 0;
    // call the user defined system definition function:
    status = init_nodes(nit);
    tic,5;
    nn = 1; NIT = nit;
    // if (!window_exists(0)) init_windows,2;
  }
  // special events (put offsets changes, etc in there)
  events,nn;
  // loop over nodes
  for (i=1;i<=idmax;i++) {
    // process go_to (PID controller) for those mechanism needing it
    if (anyof(nodes(i).pid)) status=process_go_to(i,nn);
    // propagate to Focal planes
    if (nodes(i).type=="fp") propagate_to,i;
    // callback for node id if actions defined
    if (nodes(i).action) {
      funcdef(swrite(format="%s %d %d",nodes(i).action,i,nn));
    }
    // fill position series arrays for later statistics
    (*nodes(i).pos_series)(,nn) = nodes(i).ttpos;
    (*nodes(i).poff_series)(,nn) = nodes(i).offset;
    if (nodes(i).foc_series) (*nodes(i).foc_series)(nn) = nodes(i).focpos;
    if (nodes(i).foff_series) (*nodes(i).foff_series)(nn) = nodes(i).foc_offset;
    // check limits have not been exceeded
    if (nodes(i).limit==0) continue;
    if (nodes(i).type=="fp") {
      if (anyof(abs(nodes(i).ttpos)>nodes(i).limit)) \
        error,swrite(format="%s lost\n",nodes(i).name);
    } else {
      if (anyof(abs(nodes(i).ttpos)>nodes(i).limit)) {
        write,format="%s at limit\n",nodes(i).name;
        nodes(i).ttpos = clip(nodes(i).ttpos,-nodes(i).limit,nodes(i).limit);
      }
    }
  } // end of loop over nodes
  // Do the plots
  nodes_plot,where(nodes.plot(2,)),nn;
  // handle calling oneself (or not):
  if ((end)||pause_loop||((!wrap_series)&&(nn==NIT))) { // we want to stop now
    after,-; // cancel after calls.
    if (pause_loop) { pause_loop = 0; return; }
    status = end_of_loop_stats(); // printout some stats
    if (animate_plots) for (i=0;i<=1;i++) { window,i; animate,0;}
    time_plot,where(nodes.plot(2,)); // Signal vs time plots
    write,format="The %d iterations took %f seconds\n",NIT,tac(5);
    if (postrun!=[]) status = postrun(); // call postrun function (e.g. movie)
  } else { // we want to continue
    if (delay==-1) typeReturn; 
    after,max(_(delay,1))*0.001,loop; // call oneself
    nn = (nn%NIT); // handle wrap
    nn++;
  }
}

func end_of_loop_stats(void)
/* DOCUMENT end_of_loop_stats(void)
   Whatever you want to do at the completion of the simulation
   Typically stats etc. Could also be a user function
*/
{
  for (i=1;i<=idmax;i++) { // printout some stats
    if (nodes(i).foc_series) \
      write,format="%20s TT rms=(%.3f,%.3f), focus rms=%.3fum\n",nodes(i).name,(*nodes(i).pos_series)(1,10:)(rms),(*nodes(i).pos_series)(2,10:)(rms),(*nodes(i).foc_series)(10:)(rms);
    else \
      write,format="%20s TT rms=(%.3f,%.3f)\n",nodes(i).name,(*nodes(i).pos_series)(1,10:)(rms),(*nodes(i).pos_series)(2,10:)(rms);
  }
}

func process_go_to(id,n)
{
  extern nodes;
  extern error_history;
  extern itv;

  ehdim = 200;
  if (error_history==[]) {
    error_history = array(0.,[3,idmax,ehdim,2]);
    itv = array(0.,[2,2,idmax]); // integral term, all ids
  }
  error_history = roll(error_history,[0,-1,0]);
  // error:
  error_history(id,0,) = nodes(id).go_to - nodes(id).ttpos;
  // derivative term
  dt = error_history(id,0,)-error_history(id,-1,);
  // integral term
  // it = (error_history(id,,)*exp(-(indgen(ehdim)/10.)^2)(::-1,))(sum,);
  it = itv(,id) = itv(,id)+error_history(id,0,);
  // proportional term
  pt = error_history(id,0,);
  // overall correction term:
  gains = nodes(id).pid;
  ut = gains(1)*pt + gains(2)*it + gains(3)*pt;
  // write,n,id,error_history(id,0,),dt,it,pt,ut;
  // window,2;
  // pli,error_history(id,,); fma;
  // hitReturn;
  // apply it
  // error_history(,1:ehdim/2,) *= 0;
  nodes(id).ttpos += ut;
}

func time_plot(ids)
/* DOCUMENT time_plot(ids)
   Plot of variables vs time.
   Can be overridden by a user function
*/
{
  window,0; fma;
  for (i=1;i<=numberof(ids);i++) {
    plg,(*nodes(ids(i)).pos_series)(2,),indgen(NIT)/loopfreq,color=torgb(usercol((i-1)%ncols+1)),width=3;
    plt,escapechar(nodes(ids(i)).name),xglabs,0.85-0.02*i,tosys=0,color=torgb(usercol((i-1)%ncols+1)),height=14;
  }
  xytitles,"Time [s]","TT [arcsec]",[-0.005,0.005];
  pltitle,"Nodes TT";
  limits;
  plmargin;

  if (noneof(nodes.foc_series)) return; 
  window,1; fma;
  for (i=1;i<=numberof(ids);i++) {
    if (nodes(ids(i)).foc_series) {
      plg,*nodes(ids(i)).foc_series,indgen(NIT)/loopfreq,color=torgb(usercol((i-1)%ncols+1)),width=3;
      plt,escapechar(nodes(ids(i)).name),xglabs,0.85-0.02*i,tosys=0,color=torgb(usercol((i-1)%ncols+1)),height=14;
    }
  }
  xytitles,"Time [s]","Focus [microns]",[-0.005,0.005];
  pltitle,"Nodes Focus";
  limits;
  plmargin;
}

func nodes_plot(ids,n)
/* DOCUMENT nodes_plot(ids,n)
   Called at each iteration.
   Can be overridden by a user function
   Experience shows plot time plot at each iteration is not
   very effective. This way here (position at given it) is better
   in term of understanding what's happening.
*/
{
  extern mirlimit;
  kv = array(0,10); // offset of labels per window
  icolm = icolp = 0;
  uwid = uniqwid(nodes(where(nodes.plot(2,))).plot(1,));
  if (!animate_plots) for (i=1;i<=numberof(uwid);i++) { window,uwid(i); fma; }
  // loop over requested nodes ID
  for (i=1;i<=numberof(ids);i++) {
    win = nodes(ids(i)).plot(1);
    if (nodes(ids(i)).plot(2)==0) continue; // plsys=0 means skip
    window,win;
    kv(win)++;
    plsys,nodes(ids(i)).plot(2);
    if (anyof(nodes(ids(i)).type==["mir","foc"])) {
      // Plot type for "devices": will be horizontal bars
      // Note that for most device, this will be tip, tilt and focus
      // the focus appears slightly darker on the plot.
      icolm++;
      sp = 0.05; yc = [0+sp,1-sp,1-sp,0+sp]-3*kv(win); xc = [0,0,1,1];
      plfp,[torgb(usercol((icolm-1)%ncols+1))],yc,xc*nodes(ids(i)).ttpos(1),[4]
      plfp,[torgb(usercol((icolm-1)%ncols+1))],yc-0.9,xc*nodes(ids(i)).ttpos(2),[4]
      plfp,[char(torgb(usercol((icolm-1)%ncols+1))*0.6)],yc-1.8,xc*nodes(ids(i)).focpos,[4]
      mirlimit = max(_(mirlimit,abs(nodes(ids(i)).ttpos),abs(nodes(ids(i)).focpos)));
      mirlimit *= 0.99996; // leak for when it quiets down.
      limits; limits,-1.2*mirlimit,1.05*mirlimit;
      range,-3*kv(win)-2,-1;
      xytitles,"arcsec (TT) or microns (Focus, darker)","",[0.,0.005];
      plt,escapechar(nodes(ids(i)).name),-1.15*mirlimit,-3*kv(win),color=torgb(usercol((i-1)%ncols+1)),tosys=1,justify="LH",height=14;
    } else {
      // Plot of TT or focus position at this iteration
      // Focus appears as a bigger symbol. Nice effect :-)
      icolp++;
      tfield = field(nodes(ids(i)).plot(1)+1);
      dy0 = tfield/18.;
      limits,-tfield/2,tfield/2,-tfield/2,tfield/2;
      tsym = "x"; if (nodes(ids(i)).type=="fp") tsym="o";
      ssize = 0.5+abs(nodes(ids(i)).focpos)*10;
      plp,nodes(ids(i)).ttpos(2),nodes(ids(i)).ttpos(1),color=torgb(usercol((icolp-1)%ncols+1)),symbol=tsym,width=3,size=ssize,fill=1;
      plp,tfield/2-kv(win)*dy0+dy0/2.5,-tfield/2+dy0/1.5,color=torgb(usercol((icolp-1)%ncols+1)),symbol=tsym,width=3,size=0.8,fill=1;
      plt,escapechar(nodes(ids(i)).name),-tfield/2+1.4*dy0,tfield/2-(kv(win)-0.2)*dy0+dy0/2.5,color=torgb(usercol((icolp-1)%ncols+1)),tosys=1,justify="LH",height=14;
      xytitles,"arcsec","arcsec",[0.01,0.005];
    }
    pltitle,swrite(format="Iteration %d",n);
  }
  if (animate_plots) for (i=1;i<=numberof(uwid);i++) { window,uwid(i); fma; }
}


func gen_time_series(nit,stdev,knee)
/* DOCUMENT gen_time_series(nit,stdev,knee)
   Generate time series with the statistics such as the PSD
   of this signal is constant through frequency "knee", then 
   decreases with psd=k^(-11/3). Normalises so that the signal
   rms is "stdev".
*/
{
  freq = span(0.,1.,nit/2+1)*loopfreq;
  psd = freq*0.;
  psd(where(freq<=knee)) = 1;
  psd(where(freq>knee)) = (freq(where(freq>knee))/knee)^(-11./3);
  psd = _(psd(:-1),psd(2:)(::-1));
  pha = random(nit)*2*pi;
  w = sqrt(psd)*exp(1i*pha);
  series = float(fft(w,1));
  series = series/series(rms)*stdev;
  series -= avg(series);
  return series; // float vector with correct statistics
}

// GENERAL LIBRARY functions

func escapechar(s)
/* DOCUMENT escapechar(s)
   Returns a string in which the yorick special characters
   _ and ^ have been escaped.
*/
{
  s=streplace(s,strfind("_",s,n=20),"!_");
  s=streplace(s,strfind("^",s,n=20),"!^");
  return s;
}

func mrot(ang)
/* DOCUMENT mrot(angle)
 * returns the matrix of rotation for a given angle.
 * It has to be used as follow:
 * If you want to rotate a vector of two coefficients xy=[x,y],
 * You should do rotated vector = mrot(+,)*xy(+,);
 * Angle is in degrees.
 * SEE ALSO:
 */
{
  dtor=pi/180.;
  return [[cos(ang*dtor),-sin(ang*dtor)],[sin(ang*dtor),cos(ang*dtor)]];
}

