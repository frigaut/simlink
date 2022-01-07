# Simlink
"simullink" type package for loop stability simulations - mostly geared at MAVIS

## Goal

Investigate the overall MAVIS loop stability given the complex control scheme that we have establish for the control of TT, focus and associated offloads.

## Package description

The package is made of two main files:

1. `simlink.i`: This is the main, generic file containing generic package functions. Its main function is loop(). It also contains structure definition and other utilitary functions, including plot functions.
2. `parfile`, in this case `mavis.par`: This is the system specific file that contains the system definition (in `init_nodes()`), but also the specific definition of some nodes actions, event functions (to allow for running scenario like changing gains, conditions, etc), prerun and postrun functions, etc. 

More to come. Also add sections:

## Installation

You will need yorick. This is not the place to detail how to install yorick. I have ever run it on linux and macos. On linux, many distro have packages. In archlinux (or derivatives) in particular, it can be installed from the AUR ith

```bash
paru yorick yorick-imutil yorick-yutils
```
(or yay, yaourt or any arch helper). 

Once yorick installed (and tested), you can clone this repository

```bash
git clone https://github.com/frigaut/simlink.git
cd simlink
```

## Running simlink

```bash
yorick -i simlink.i
loop,"mavis.par",init=1
```

This should open two graphic windows and start running the loop. You still have access to the yorick prompt during the loop execution, so you can change gains, look up variables, change the frame rate (delay=dead time per iteration in ms to slow down the display), etc. 

To end the simulation:

```bash
loop,end=1
```

Note that for further calls to `loop()`, you do not need to exit yorick. Just modify the code in `mavis.par` to your liking, then re-run the simulation with another call to `loop,"mavis.par",init=1`. It will re-read `mavis.par` and re-start the loop and graphic displays (the window will not be re-created, so it will keep whatever arrangement you have put them on on your screen). Beware not to call `loop()` again without having stopped it first (with `loop,end=1` or with loop having naturally come to the end of its iterations), otherwise another instance of `loop()` will be started in parallel and it will be messy. 

A typical run include:

- Adjusting `mavis.par` to your linking: Adding nodes, modifying node properties, adjusting the event/scenario series by changing the content of the corresponding `event()` function.
- Re-running `loop()` with the new config.

### Nodes definition

"nodes" are any element of the optical/loop system. It may be a source (e.g. ngs), some perturbation (e.g. uplink or downlink turbulence), an optical element (DSM, telmount), whether active or inactive (e.g. lgs_zoom), or a focal plane (WFS, imager).

- nodes are sequential, according to the order you define them in `init_nodes()`.

- A node is defined by a structure element. Adding a node is just adding an element to this structure, as follow:

  ```bash
  grow,nodes,node(id=id++,name="ngs",path=scipath+ngspath);
  ```

The node structure definition include the following elements that can be defined (there are others, but not intended for user input):

- `nodes.name`(string): the name of the node
- `nodes.path`(long): The optical path this node belongs to. This node will only be affecting the path it is in. `path` is compound. There is an arbitrary large number of path, but they have to yorick -i simlink.i
- `nodes.action`(string): this is the name of a function to be called when "processing" this node. This allows things like "for this WFS, take the measurement and direct it to the DSM", or "add turbulence uplink" or anything you want to define in the function.
- `nodes.type`(string) : can be nothing, "mir", "foc" or "fp". "mir" or "foc",  are just for indicating the display/plot this node should be used for. "fp" i smore important and indicate where all of the other nodes (in this "path") should be propagated to.
- `nodes.plot`(long): two element array containing the window (0,1,...) and the plsys on which you want this node to be plotted. plsys for now can only be 0 (no plot) or 1 (plot). Generally, try to restrict the number of window to a few (I use 2: 0 and 1).
- `nodes.delay`(long): "loop" delay in integer number of frame. 0: no delay (in reality, one frame delay the way the loop implementation is structured right now).
- `nodes.freqratio`(long): if larger than one, the action on this node is only effected every freqratio iterations. Not extensively tested.
- `nodes.ts` (float): 2 element array with rms of desired random signal, and knee in frequency (in Hertz, usually around 1).
- `nodes.fs`(float): same for focus.
- `nodes.offset` and `nodes.foc_offset` (float): respectively 2 element array (tip tilt) and a single scalar value containing the offset. Useful for setting things off-axis, of inducing a focus offset. Mostly useful for "fp". If you want to offset a mirror for instance, you should use 
  `nodes.ttpos += some value`.
- `nodes.action_on`(string): For use in generic action function (e.g. you can defined a generic "direct the measurements toward a node" and defined the node with action_on). It allows to re-use a function for several elements (e.g. in MAVIS the 8 LGS WFSs) and drastically reduce the length of the code. See example in `mavis.par`.

### Other useful tricks

`id_match(name)` returns the node id that corresponds to "name". 

The `events()` function is called before every iterations with the iteration number as an argument. This allows to build scenarii in which you can define something happening at some point in time (some iteration). For instance, for offseting the NGS position at iteration 100:

```C
func events(n)
// n is iteration number in main loop() function
{
  extern nodes,delay;
  // change NGS WFS offset at iteration 100:
  if (n>100) nodes(id_match("ngs_wfs")).offset = [0.,2.0];
}
```

Complex scenarii can be built this way, including also slowing down the display rate at strategic moment to better see what is happening, etc. For a more complex scenarii, see function `scenario1()` in `mavis.par`.

## Examples

`mavis.par` is the most complete example, but it is a bit complex and can be overwhelming if you don't know the package. I have written a basic example in `basic.par`.

## Development plan

- [x] Add focus behaviour and compensation
- [x] Add loop delay
- [x] Add 8 LGSs 
- [x] ...and the whole scheme, with offload to the LGSF_FM? (partially done, offload to 1 FSM er couple of lgs done)
- [x] Split graphics into NGS and LGS? Clearer to understand graphics.
- [x] Make movie of graphic window when running loop (kinda done, use `wf-recorder -g "$(slurp)"` in bash and select the area of the screen, it starts recording at once so you should be ready to start the yorick job).
- [x] Nicer graphics
- [ ] A GUI (which is possible in yorick using e.g. a python GUI framework like GTK+Glade or others), would add interesting possibilities, like e.g. being able to really run the simulation like if at the telescope, inducing offsets, changing gains, etc.
- [ ] Add component various loop frequencies and reaction time - at least put filter on slow component otherwise the offload appears to jump to fast when offloading once in a while large quantities.
- [ ] Add rotation? link to telescope elevation?

## Contributors

Up to now, francois.rigaut@anu.edu.au.



