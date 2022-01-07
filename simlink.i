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

simlink_version = 1.4;

// Structure declaration
struct node {
  string name; // name of the node
  int path; // sum of path to which the node pertains, for instance
  // 001: science = 1, 010: ngs = 2, 100: lgs = 4
  // e.g. path=7 ➜ all of science, ngs, lgs
  // path=6 ➜ science and lgs, etc, can add ad libitum other e.g. LGS
  float offset(2); // offset of the node (useful for off-axis things)
  float foc_offset; // offset of the node (useful for off-axis things)
  string action; // name of a callback function to effect an action
  string action_on; // for use in generic function allow to pass which node the action has to apply on
  string type; // "mir", "foc", nothing or "fp" (focal plane)
  long plot(2); // window and plsys in which this node has to be plot. plsys=0 means no plot.
  float ts(2); // TT perturbation time series parameters: stdev,knee
  float fs(2); // Focus perturbation time series parameters: stdev,knee
  long delay; // "Loop" delay in frames for this node. 0 = no delay
  float freqratio; // ratio of control rate for this node wrt to base frequency. e.g. 10 = freq/10
  // INTERNAL PARAMETERS (not intended to be messed with)
  int id; // assigned by init_nodes()
  float ttpos(2); // current TT position of node
  float focpos; // current focus position of the node
  pointer tt_turb_series; // pointer to TT time series (perturbation)
  pointer foc_turb_series; // pointer to focus time series (perturbation)
  pointer pos_series; // pointer to 2xNit array to receive TT positions versus time. for rms etc 
  pointer poff_series; // pointer to 2xNit array to receive TT offsets versus time. for rms etc 
  pointer foc_series; // pointer to Nit array to receive focus versus time. for rms etc 
  pointer foff_series; // pointer to Nit array to receive focus offsets versus time. for rms etc 
};

// Functions definitions

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
  extern mirlimit,nn,NIT;

  if (init) {
    // init things
    // The parfile is where all the system is defined, as well as
    // callback functions (actions)
    include,parfile,1;
    // possibility to run a prerun function (e.g. to record a movie)
    if (prerun!=[]) status = prerun();
    if (animate_plots) animate,1;
    mirlimit = 0.; // Just for graphics
    // used to slow or pause display + resume with initial value of delay
    delay_start = delay; 
    // call the user defined system definition function:
    status = init_nodes(nit);
    nn = 1; NIT = nit;
  }
  // special events (put offsets changes, etc in there)
  events,nn;
  // loop over nodes
  for (i=1;i<=idmax;i++) {
    // propagate to Focal planes
    if (nodes(i).type=="fp") propagate_to,i;
    // callback for node id if actions defined
    if (nodes(i).action) {
      funcdef(swrite(format="%s %d %d",nodes(i).action,i,nn));
    }
    // fill position series arrays for later statistics
    (*nodes(i).pos_series)(,nn) = nodes(i).ttpos;
    (*nodes(i).poff_series)(,nn) = nodes(i).offset;
    (*nodes(i).foc_series)(nn) = nodes(i).focpos;
    (*nodes(i).foff_series)(nn) = nodes(i).foc_offset;
  } // end of loop over nodes
  // Do the plots
  nodes_plot,where(nodes.plot(2,)),nn;
  // handle calling oneself (or not):
  if ((end)||((!wrap_series)&&(nn==NIT))) { // we want to stop now
    status = end_of_loop_stats(); // printout some stats
    if (animate_plots) animate,0;
    time_plot,where(nodes.plot(2,)); // Signal vs time plots
    after,-; // cancel after calls.
    if (postrun!=[]) status = postrun(); // call postrun function (e.g. movie)
  } else { // we want to continue
    if (delay==-1) hitReturn; 
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
    write,format="%20s rms=(%.3f,%.3f)\n",nodes(i).name,(*nodes(i).pos_series)(1,rms),(*nodes(i).pos_series)(2,rms);
  }
}

func time_plot(ids)
/* DOCUMENT time_plot(ids)
   Plot of variables vs time.
   Can be overridden by a user function
*/
{
  for (i=1;i<=numberof(ids);i++) {
    plg,(*nodes(ids(i)).pos_series)(2,),color=torgb(gruvbox((i-1)%7+1));
    plt,escapechar(nodes(ids(i)).name),0.50,0.85-0.02*i,tosys=0,color=torgb(gruvbox((i-1)%7+1)),height=14;
  }
  xytitles,"Iteration","arcsec (TT) or micron (focus)",[0.01,0.005];
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
      sp = 0.05; yc = [0+sp,1-sp,1-sp,0+sp]-3*kv(win); xc = [0,0,1,1];
      plfp,[torgb(gruvbox((i-1)%7+1))],yc,xc*nodes(ids(i)).ttpos(1),[4]
      plfp,[torgb(gruvbox((i-1)%7+1))],yc-1,xc*nodes(ids(i)).ttpos(2),[4]
      plfp,[char(torgb(gruvbox((i-1)%7+1))*0.6)],yc-2,xc*nodes(ids(i)).focpos,[4]
      mirlimit = max(_(mirlimit,abs(nodes(ids(i)).ttpos),abs(nodes(ids(i)).focpos)));
      mirlimit *= 0.99999; // leak for when it quiets down.
      limits; limits,-1.2*mirlimit,1.05*mirlimit;
      range,-3*kv(win)-2,-1;
      xytitles,"arcsec (TT) or microns (Focus)","",[0.,0.005];
      plt,escapechar(nodes(ids(i)).name),-1.15*mirlimit,-3*kv(win),color=torgb(gruvbox((i-1)%7+1)),tosys=1,justify="LH",height=14;
    } else {
      // Plot of TT position at this iteration
      // Focus appears as a bigger symbol. Nice effect :-)
      tfield = field(nodes(ids(i)).plot(1)+1);
      dy0 = tfield/18.;
      limits,-tfield/2,tfield/2,-tfield/2,tfield/2;
      tsym = "x"; if (nodes(ids(i)).type=="fp") tsym="o";
      ssize = 0.5+abs(nodes(ids(i)).focpos)*10;
      plp,nodes(ids(i)).ttpos(2),nodes(ids(i)).ttpos(1),color=torgb(gruvbox((i-1)%7+1)),symbol=tsym,width=3,size=ssize,fill=1;
      plp,tfield/2-kv(win)*dy0+dy0/2.5,-tfield/2+dy0/1.5,color=torgb(gruvbox((i-1)%7+1)),symbol=tsym,width=3,size=0.8,fill=1;
      plt,escapechar(nodes(ids(i)).name),-tfield/2+1.4*dy0,tfield/2-(kv(win)-0.2)*dy0+dy0/2.5,color=torgb(gruvbox((i-1)%7+1)),tosys=1,justify="LH",height=14;
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
