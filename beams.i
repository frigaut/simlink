/*******  Beams.i package functions **********
Invoke with, e.g.:
loop,"mavis-simple.par",500
*********************************************/
beams_version = 1.3;

pldefault,dpi=120;

// Structure declaration
struct node {
  string name; // name of the node
  int path; // sum of path to which the node pertains
  // 001: ngs = 1
  // 010: lgs = 2
  // 100: science = 4
  // e.g. path=7 ➜ all of science, ngs, lgs
  // path=6 ➜ science and lgs, etc
  float offset(2); // offset of the node (useful for off-axis things)
  string action; // name of a callback function to effect an action
  string action_on; // for use in generic function allow to pass which node the action has to apply on
  string type; // "source",nothing or "fp" (focal plane)
  long plot(2); // window and plsys in which this node has to be plot. plsys=0 means no plot.
  float ts(2); // perturbation time series parameters: stdev,knee
  long delay; // delay in frame for this node
  // INTERNAL PARAMETERS (not intended to be messed with)
  int id; // assigned by init_nodes()
  float ttpos(2); // current TT position of node
  float focpos; // current focus position of the node
  float ttupdate(2); // when updating, diff between previous and current
  float focupdate; // same for focus
  pointer tseries; // pointer to time series (perturbation), 2 because X,Y
  pointer pos_series; // pointer to 2xNit array to receive positions versus time. for rms etc 
  pointer off_series; // pointer to 2xNit array to receive offsets versus time. for rms etc 
  float freqratio; // ratio of control rate for this node wrt to base frequency. e.g. 10 = freq/10
};

// beams.i function definitions

func winstart(zoom)
/* DOCUMENT initialise specific plotting windows
*/
{
  if (!zoom) zoom=1.5; 
  plsplit,5,1,win=1,style="nobox.gs",margin=-0.01,vp=[0.01,0.78,0.48,0.77],\
    height=long(480*zoom),width=long(1200*zoom),dpi=long(140*zoom); 
  pljoin,[3,4]; pljoin,[1,2]; 
}
// if (!window_exists(1)) winstart;

func uniqwid(wid)
// find unique WID number in list of wid
{
  // vector of all requested window ID
  wid = wid(sort(wid));
  uwid = _(wid(where(wid(dif))),wid(0));
  return uwid;
}

func path_match(path1,path2)
/* DOCUMENT path_match(path1,path2)
   Matches two paths, 1 if the same, 0 if not
*/
{ 
  return (path1&path2); 
}


func id_match(name)
/* DOCUMENT id_match(name)
   Return id of matching path name, 0 if no match
*/
{
  if (numberof(where(nodes.name==name))==0) return 0;
  return nodes.id(where(nodes.name==name));
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


func loop(parfile,nit)
/* DOCUMENT loop(parfile,nit)
   Main function. loop over the whole system, iteration by
   iteration. Applies special callbacks (actions) for the nodes
   for which they are required/defined. Plots and accumulate 
   statistics. Final printouts.
*/
{
  extern nodes,delay_start;

  include,parfile,1;
  if (animate_plots) animate,1;
  mirlimit = 0.;
  delay_start = delay;
  status = init_nodes(nit);
  // Loop over iterations
  for (n=1;n<=nit;n++) {
    // special events (put offsets changes, etc in there)
    events,n;
    // loop over nodes
    for (i=1;i<=idmax;i++) {
      // propagate to Focal planes
      if (nodes(i).type=="fp") propagate_to,i;
      // callback for node id if actions defined
      if (nodes(i).action) {
        funcdef(swrite(format="%s %d %d",nodes(i).action,i,n));
      }
      // fill position series arrays for later statistics
      (*nodes(i).pos_series)(,n) = nodes(i).ttpos;
      (*nodes(i).off_series)(,n) = nodes(i).offset;
    } // end of loop over nodes
    // Plots
    nodes_plot,where(nodes.plot(2,)),n;
    if (delay==-1) hitReturn; else pause,delay;
  }
  for (i=1;i<=idmax;i++) {
    write,format="%20s rms=(%.3f,%.3f)\n",nodes(i).name,(*nodes(i).pos_series)(1,rms),(*nodes(i).pos_series)(2,rms);
  }
  if (animate_plots) animate,0;
  time_plot,where(nodes.plot(2,));
}


func time_plot(ids)
{
  // window,0;
  // fma;
  for (i=1;i<=numberof(ids);i++) {
    plg,(*nodes(ids(i)).pos_series)(2,),color=torgb(gruvbox((i-1)%7+1));
    plt,escapechar(nodes(ids(i)).name),0.50,0.85-0.02*i,tosys=0,color=torgb(gruvbox((i-1)%7+1)),height=14;
  }
  limits;
  plmargin;
}

func nodes_plot(ids,n)
{
  extern mirlimit;
  kv = array(0,10); // offset of labels per window
  uwid = uniqwid(nodes(where(nodes.plot(2,))).plot(1,));
  if (!animate_plots) for (i=1;i<=numberof(uwid);i++) { window,uwid(i); fma; }
  for (i=1;i<=numberof(ids);i++) {
    win = nodes(ids(i)).plot(1);
    if (nodes(ids(i)).plot(2)==0) continue;
    window,win;
    kv(win)++;
    plsys,nodes(ids(i)).plot(2);
    if (nodes(ids(i)).type=="mir") {
      sp = 0.05; yc = [0+sp,1-sp,1-sp,0+sp]-2*kv(win); xc = [0,0,1,1];
      plfp,[torgb(gruvbox((i-1)%7+1))],yc,xc*nodes(ids(i)).ttpos(1),[4]
      plfp,[torgb(gruvbox((i-1)%7+1))],yc-1,xc*nodes(ids(i)).ttpos(2),[4]
      mirlimit = max(_(mirlimit,abs(nodes(ids(i)).ttpos)));
      limits; limits,-1.2*mirlimit,1.05*mirlimit;
      range,-2*kv(win)-1,-1;
      // xytitles,"arcsec","";
      plt,escapechar(nodes(ids(i)).name),-1.15*mirlimit,-2*kv(win),color=torgb(gruvbox((i-1)%7+1)),tosys=1,justify="LH",height=14;
    } else {
      tfield = field(nodes(ids(i)).plot(1)+1);
      dy0 = tfield/18.;
      limits,-tfield/2,tfield/2,-tfield/2,tfield/2;
      tsym = "x"; if (nodes(ids(i)).type=="fp") tsym="o";
      plp,nodes(ids(i)).ttpos(2),nodes(ids(i)).ttpos(1),color=torgb(gruvbox((i-1)%7+1)),symbol=tsym,width=3,size=0.8,fill=1;
      plp,tfield/2-kv(win)*dy0+dy0/2.5,-tfield/2+dy0/1.5,color=torgb(gruvbox((i-1)%7+1)),symbol=tsym,width=3,size=0.8,fill=1;
      plt,escapechar(nodes(ids(i)).name),-tfield/2+1.4*dy0,tfield/2-(kv(win)-0.2)*dy0+dy0/2.5,color=torgb(gruvbox((i-1)%7+1)),tosys=1,justify="LH",height=14;
    }
    pltitle,swrite(format="Iteration %d",n);
  }
  if (animate_plots) for (i=1;i<=numberof(uwid);i++) { window,uwid(i); fma; }
}


func generic(id,it) { }

func gen_time_series(nit,stdev,knee)
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
