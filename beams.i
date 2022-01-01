require,"yao_util.i"; // for escapechar

gain_ngs = -0.6*[1,1];
gain_lgs_foc = -0.6*0;
gain_lgs_fsm = -0.01; //0.6;
gain_dsm_offload = 0.0002;
gain_fsm_offload = -0.002;
field = 0.2; 
loopfreq = 1000.;

struct node {
  int id;
  string name;
  int path; // sum of 1:ngs, 2:science, 3:lgs 
  // 001: ngs = 1
  // 010: lgs = 2
  // 100: science = 4
  // e.g. path=7 ➜ all of science, ngs, lgs
  // path=6 ➜ science and lgs, etc
  float ttpos(2);
  float offset(2);
  float focpos;
  float ttupdate(2);
  float focupdate;
  string action;
  string type; // "source",nothing or "fp" (focal plane)
  long plot; // plsys in which it has to be plot
  float field;
};

func winstart(zoom)
{
  if (!zoom) zoom=1.5; 
  plsplit,5,1,win=1,style="nobox.gs",margin=-0.01,vp=[0.01,0.78,0.48,0.77],\
    height=long(480*zoom),width=long(1200*zoom),dpi=long(140*zoom); 
  pljoin,[3,4]; pljoin,[1,2]; 
}
// if (!window_exists(1)) winstart;

func init_nodes(void)
{
  extern nodes,idmax,field;
  nodes = [];
  id = 1;
  lgs1off = [0.1,0.];
  grow,nodes,node(id=id++,name="ngs",path=5);
  grow,nodes,node(id=id++,name="lgs",ttpos=lgs1off,offset=lgs1off,path=2,action="lgs",plot=1); // LGS launch jitter mirror will drive this
  grow,nodes,node(id=id++,name="turb",path=7,action="turb",plot=1);
  grow,nodes,node(id=id++,name="telmount",path=5,plot=1); // LGS are installed on the mount, so mount motion doesn't affect them
  grow,nodes,node(id=id++,name="dsm",path=7,action="dsm",plot=1);
  // grow,nodes,node(id=id++,name="lgs_focus_stage",path=2);
  grow,nodes,node(id=id++,name="lgs_fsm",path=2,plot=1); //,action="lgs_fsm");
  grow,nodes,node(id=id++,name="lgs_wfs",path=2,type="fp",offset=lgs1off,action="lgs_wfs",plot=1);
  grow,nodes,node(id=id++,name="ngs_focus_stage",path=1);
  grow,nodes,node(id=id++,name="ngs_wfs",path=1,action="ngs_wfs",type="fp",plot=1);
  // grow,nodes,node(id=id++,name="sci_objective",path=4);
  // grow,nodes,node(id=id++,name="imager",path=4,type="fp");
  idmax = id-1;
  field = [0.6,10.,0.1];
}

func path_match(path1,path2) { return (path1&path2); }

func id_match(name)
{
  if (numberof(where(nodes.name==name))==0) return 0;
  return nodes.id(where(nodes.name==name));
}

// func propagate(id)
// {
//   extern nodes;
//   for (i=id+1;i<=idmax;i++) {
//     if (path_match(nodes(i).path,nodes(id).path)) {
//       // downstream node is in same path, affected by current node
//       nodes(i).ttpos  += nodes(id).ttupdate;
//       nodes(i).focpos += nodes(id).focupdate;
//     }
//   }
// }
func propagate_to(id)
{
  extern nodes;
  path = nodes(id).path;
  // what nodes are in this path?
  w = where(path_match(path,nodes.path))(:-1);
  nodes(id).ttpos = nodes(w).ttpos(,sum);
  nodes(id).focpos = sum(nodes(w).focpos);
}

func loop(nit)
{
  extern nodes;
  status = init_nodes();
  fma;
  for (n=1;n<=nit;n++) {
    for (i=1;i<=idmax;i++) {
      if (nodes(i).type=="fp") propagate_to,i;
      // change state of node id
      if (nodes(i).action) {
        funcdef(swrite(format="%s %d",nodes(i).action,i));
      }
    }
    if (!plotmode) plotmode=2;
    if (plotmode==1) {
      nodes_plot,[id_match("lgs"),id_match("turb"),\
                id_match("lgs_fsm"),id_match("lgs_wfs")],n;

    } else if (plotmode==2) {
      // nodes_plot2,[id_match("lgs"),id_match("lgs_wfs"),\
      //           id_match("ngs"),id_match("ngs_wfs")];
      nodes_plot2,where(nodes.plot);
    }
    // nodes_plot,[id_match("turb"),id_match("dsm"),id_match("ngs_wfs")],n;
    // pm,nodes.ttpos;
    // typeReturn;
  }
}

func nodes_plot(ids,it)
{
  k = 0;
  for (i=1;i<=numberof(ids);i++) {
    plp,nodes(ids(i)).ttpos(1),it,color=torgb(gruvbox(i)),symbol="o",size=0.2;
    // plp,nodes(ids(i)).focpos(1),it,color=torgb(gruvbox(i)),symbol="x",size=0.2;
    plt,escapechar(nodes(ids(i)).name),0.13,0.38+0.02*k++,tosys=0,color=torgb(gruvbox(i));
  }
}

func nodes_plot2(ids)
{
  fma; dy0 = 0.02;
  for (i=1;i<=numberof(ids);i++) {
    plsys,nodes(ids(i)).plot;
    tfield = field(nodes(ids(i)).plot);
    limits,-tfield/2,tfield/2,-tfield/2,tfield/2;
    plp,nodes(ids(i)).ttpos(2),nodes(ids(i)).ttpos(1),color=torgb(gruvbox(i)),symbol="o",size=1.0-0.1*i,fill=1;
    plt,escapechar(nodes(ids(i)).name),0.23,0.83-(i-1)*dy0,color=torgb(gruvbox(i));
  }
}

// node action functions
func turb(id)
{
  extern nodes;
  // add random walk with spring, in TT:
  nodes(id).ttupdate = (0.0005*random_n(2)-nodes(id).ttpos*0.0001);
  nodes(id).ttpos += nodes(id).ttupdate;
  // same in focus:
  nodes(id).focupdate = (0.001*random_n()-nodes(id).focpos*0.0001);
  nodes(id).focpos += nodes(id).focupdate;
}

func lgs(id)
// add a little bit of jitter too.
{
  extern nodes;
  // add random walk with spring
  nodes(id).ttupdate = (0.0005*random_n(2)-(nodes(id).ttpos-nodes(id).offset)*0.0005);
  nodes(id).ttpos += nodes(id).ttupdate;
  nodes(id).focupdate = (0.0001*random_n()-nodes(id).focpos*0.00001);
  nodes(id).focpos += nodes(id).focupdate;
}

func ngs_wfs(id)
{
  extern nodes;
  // ttpos is the error reported by the ngs wfs
  // let's plug that into the DSM:
  id2 = id_match("dsm");
  nodes(id2).ttpos += gain_ngs*nodes(id).ttpos;
}

func lgs_wfs(id)
{
  extern nodes;
  // correct focus with dsm
  id2 = id_match("dsm");
  nodes(id2).focpos += gain_lgs_foc*nodes(id).focpos;
  // correct tt with LGS FSM
  id2 = id_match("lgs_fsm");
  nodes(id2).ttpos += gain_lgs_fsm*(nodes(id).ttpos-nodes(id).offset);
}

func dsm(id)
// dsm offload to mount
{
  extern nodes;
  id2 = id_match("telmount");
  nodes(id2).ttpos += gain_dsm_offload*nodes(id).ttpos;
}

func lgs_fsm(id)
// fsm offload to launch jitter mirror
{
  extern nodes;
  id2 = id_match("lgs");
  nodes(id2).ttpos += gain_fsm_offload*nodes(id).ttpos;
}

func generic(void) { }

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
  return series;
}