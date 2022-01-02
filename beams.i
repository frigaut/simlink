/*******  Beams.i package functions **********/
require,"yao_util.i"; // for escapechar

beams_version = 1.1;

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
  string type; // "source",nothing or "fp" (focal plane)
  long plot; // plsys in which this node has to be plot
  float ts(2); // perturbation time series parameters: stdev,knee
  // INTERNAL PARAMETERS (not intended to be messed with)
  int id; // assigned by init_nodes()
  float ttpos(2); // current TT position of node
  float focpos; // current focus position of the node
  float ttupdate(2); // when updating, diff between previous and current
  float focupdate; // same for focus
  pointer tseries; // pointer to time series (perturbation), 2 because X,Y
  pointer pos_series; // pointer to 2xNit array to receive position versus time. for rms etc 
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
  extern nodes;

  include,parfile,1;

  status = init_nodes(nit);
  fma;
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
    } // end of loop over nodes
    // Plots
    if (!plotmode) plotmode=2;
    if (plotmode==1) nodes_plot,where(nodes.plot),n; \
    else if (plotmode==2) nodes_plot2,where(nodes.plot),n;
    pause,delay;
  }
  for (i=1;i<=idmax;i++) {
    write,format="%20s rms=(%.3f,%.3f)\n",nodes(i).name,(*nodes(i).pos_series)(1,rms),(*nodes(i).pos_series)(2,rms);
  }
  time_plot,where(nodes.plot);
}

func nodes_plot(ids,it)
{
  k = 0;
  for (i=1;i<=numberof(ids);i++) {
    plp,nodes(ids(i)).ttpos(1),it,color=torgb(gruvbox((i-1)%7+1)),symbol="o",size=0.2;
    // plp,nodes(ids(i)).focpos(1),it,color=torgb(gruvbox((i-1)%7+1)),symbol="x",size=0.2;
    plt,escapechar(nodes(ids(i)).name),0.10,0.83-0.02*k++,tosys=0,color=torgb(gruvbox((i-1)%7+1));
  }
  limits;
}

func time_plot(ids)
{
  // window,1;
  fma;
  for (i=1;i<=numberof(ids);i++) {
    plg,(*nodes(ids(i)).pos_series)(2,),color=torgb(gruvbox((i-1)%7+1));
    plt,escapechar(nodes(ids(i)).name),0.10,0.83-0.02*i,tosys=0,color=torgb(gruvbox((i-1)%7+1));
  }
  limits;
  plmargin;
}

func nodes_plot2(ids,n)
{
  fma; dy0 = 0.02; 
  for (i=1;i<=numberof(ids);i++) {
    if (nodes(ids(i)).plot==0) continue;
    plsys,nodes(ids(i)).plot;
    tfield = field(nodes(ids(i)).plot);
    dy0 = tfield/20.;
    limits,-tfield/2,tfield/2,-tfield/2,tfield/2;
    tsym = "x"; if (nodes(ids(i)).type=="fp") tsym="o";
    plp,nodes(ids(i)).ttpos(2),nodes(ids(i)).ttpos(1),color=torgb(gruvbox((i-1)%7+1)),symbol=tsym,width=3,size=1.0-0.05*i,fill=1;
    plp,tfield/2-i*dy0,-tfield/2+dy0,color=torgb(gruvbox((i-1)%7+1)),symbol=tsym,width=3,size=1.0-0.05*i,fill=1;
    plt,escapechar(nodes(ids(i)).name),-tfield/2+1.6*dy0,tfield/2-(i-0.2)*dy0,color=torgb(gruvbox((i-1)%7+1)),tosys=1,justify="LH";
    pltitle,swrite(format="Iteration %d",n);
  }
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