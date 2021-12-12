gain_ngs = -0.5*[1,1];
gain_lgs = -0.2;
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
  float focpos;
  float ttupdate(2);
  float focupdate;
  string action;
};

func init_nodes(void)
{
  extern nodes,idmax;
  nodes = [];
  id = 1;
  grow,nodes,node(id=id++,name="star",ttpos=[1.,0.],path=7,action="star");
  grow,nodes,node(id=id++,name="telmount",path=7);
  grow,nodes,node(id=id++,name="dsm",path=7);
  grow,nodes,node(id=id++,name="lgs_focus_stage",path=2);
  grow,nodes,node(id=id++,name="lgs_fsm",path=2);
  grow,nodes,node(id=id++,name="lgs_wfs",path=2);
  grow,nodes,node(id=id++,name="ngs_focus_stage",path=1);
  grow,nodes,node(id=id++,name="ngs_wfs",path=1,action="ngs_wfs");
  grow,nodes,node(id=id++,name="sci_objective",path=4);
  grow,nodes,node(id=id++,name="imager",path=4);
  idmax = id-1;
}

func path_match(path1,path2) { return (path1&path2); }

func id_match(name)
{
  if (numberof(where(nodes.name==name))==0) return 0;
  return nodes.id(where(nodes.name==name));
}

func propagate(id)
{
  extern nodes;
  for (i=id+1;i<=idmax;i++) {
    if (path_match(nodes(i).path,nodes(id).path)) {
      // downstream node is in same path, affected by current node
      nodes(i).ttpos  += nodes(id).ttupdate;
      nodes(i).focpos += nodes(id).focupdate;
    }
  }
}

func loop(nit)
{
  extern nodes;
  status = init_nodes();
  fma;
  for (n=1;n<=nit;n++) {
    for (i=1;i<=idmax;i++) {
      // change state of node id
      if (nodes(i).action) {
        // write,format="Calling %s\n",nodes(i).action;
        funcdef(swrite(format="%s %d",nodes(i).action,i));
      }
      // propagate for given path
      propagate,i;
    }
    nodes_plot,[id_match("star"),id_match("dsm"),id_match("imager")],n;
    pm,nodes.ttpos;
    // typeReturn;
  }
}

func nodes_plot(ids,it)
{
  k = 0;
  for (i=1;i<=numberof(ids);i++) {
    plp,nodes(i).ttpos(1),it,color=torgb(gruvbox(i)),symbol="o",size=0.2;
    // plp,nodes(i).focpos(1),it,color=torgb(gruvbox(i)),symbol="x",size=0.2;
    plt,nodes(i).name,0.13,0.38+0.02*k++,tosys=0,color=torgb(gruvbox(i));
  }
}

// node action functions
func star(id)
{
  extern nodes;
  // add random walk with spring
  nodes(id).ttupdate = (0.05*random_n(2)-nodes(id).ttpos*0.1);
  nodes(id).ttpos += nodes(id).ttupdate;
  nodes(id).focupdate = (0.001*random_n()-nodes(id).focpos*0.0001);
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
  id2 = id_match("dsm");
  nodes(id2).focpos += gain_lgs*nodes(id).focpos;
}

func generic(void) { }
