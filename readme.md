Dymos:  Open Source Optimization of Dynamic Multidisciplinary Systems
=====================================================================

[![Build Status](https://travis-ci.com/OpenMDAO/dymos.svg?token=tUBGTjUY1qBbh4Htx3Sr&branch=master)](https://travis-ci.com/OpenMDAO/dymos) [![Coverage Status](https://coveralls.io/repos/github/OpenMDAO/dymos/badge.svg?branch=master&t=dJxu2Q)](https://coveralls.io/github/OpenMDAO/dymos?branch=master)


Dymos is a framework for the simulation and optimization of dynamical systems within the OpenMDAO Multidisciplinary Analysis and Optimization environment.
Dymos leverages implicit and explicit simulation techniques to simulate generic dynamic systems of arbitary complexity.  

The software has two primary objectives:
- Provide a generic ODE integration interface that allows for the analysis of dynamical systems.
- Allow the user to solve optimal control problems involving dynamical multidisciplinary systems.

Installation
------------

```
python -m pip install git+https://github.com/OpenMDAO/dymos.git
```

Documentation
-------------

Online documentation is available at [https://openmdao.github.io/dymos/](https://openmdao.github.io/dymos/)


Defining Ordinary Differential Equations
----------------------------------------

The first step in simulating or optimizing a dynamical system is to define the ordinary
differential equations to be integrated.  The user first builds an OpenMDAO model which has outputs
that provide the rates of the state variables.  This model can be an OpenMDAO model of arbitrary
complexity, including nested groups and components, layers of nonlinear solvers, etc.

When setting up a phase, we can add state variables, dynamic controls, and design parameters to
the phase, tell Dymos how to the value of each should be connected to the ODE system, tell Dymos
the variable paths in the system that contain the rates of our state variables that are to be
integrated.


    import numpy as np
    from openmdao.api import ExplicitComponent
    

    class BrachistochroneEOM(ExplicitComponent):
    
        def initialize(self):
            self.metadata.declare('num_nodes', types=int)
    
        def setup(self):
            nn = self.metadata['num_nodes']
    
            # Inputs
            self.add_input('v',
                           val=np.zeros(nn),
                           desc='velocity',
                           units='m/s')
    
            self.add_input('g',
                           val=9.80665*np.ones(nn),
                           desc='gravitational acceleration',
                           units='m/s/s')
    
            self.add_input('theta',
                           val=np.zeros(nn),
                           desc='angle of wire',
                           units='rad')
    
            self.add_output('xdot',
                            val=np.zeros(nn),
                            desc='velocity component in x',
                            units='m/s')
    
            self.add_output('ydot',
                            val=np.zeros(nn),
                            desc='velocity component in y',
                            units='m/s')
    
            self.add_output('vdot',
                            val=np.zeros(nn),
                            desc='acceleration magnitude',
                            units='m/s**2')
    
            self.add_output('check',
                            val=np.zeros(nn),
                            desc='A check on the solution: v/sin(theta) = constant',
                            units='m/s')
    
            # Setup partials
            arange = np.arange(self.metadata['num_nodes'])
    
            self.declare_partials(of='vdot', wrt='g', rows=arange, cols=arange, val=1.0)
            self.declare_partials(of='vdot', wrt='theta', rows=arange, cols=arange, val=1.0)
    
            self.declare_partials(of='xdot', wrt='v', rows=arange, cols=arange, val=1.0)
            self.declare_partials(of='xdot', wrt='theta', rows=arange, cols=arange, val=1.0)
    
            self.declare_partials(of='ydot', wrt='v', rows=arange, cols=arange, val=1.0)
            self.declare_partials(of='ydot', wrt='theta', rows=arange, cols=arange, val=1.0)
    
            self.declare_partials(of='check', wrt='v', rows=arange, cols=arange, val=1.0)
            self.declare_partials(of='check', wrt='theta', rows=arange, cols=arange, val=1.0)
    
        def compute(self, inputs, outputs):
            theta = inputs['theta']
            cos_theta = np.cos(theta)
            sin_theta = np.sin(theta)
            g = inputs['g']
            v = inputs['v']
    
            outputs['vdot'] = g*cos_theta
            outputs['xdot'] = v*sin_theta
            outputs['ydot'] = -v*cos_theta
            outputs['check'] = v/sin_theta
    
        def compute_partials(self, inputs, jacobian):
            theta = inputs['theta']
            cos_theta = np.cos(theta)
            sin_theta = np.sin(theta)
            g = inputs['g']
            v = inputs['v']
    
            jacobian['vdot', 'g'] = cos_theta
            jacobian['vdot', 'theta'] = -g*sin_theta
    
            jacobian['xdot', 'v'] = sin_theta
            jacobian['xdot', 'theta'] = v*cos_theta
    
            jacobian['ydot', 'v'] = -cos_theta
            jacobian['ydot', 'theta'] = v*sin_theta
    
            jacobian['check', 'v'] = 1/sin_theta
            jacobian['check', 'theta'] = -v*cos_theta/sin_theta**2
 

Integrating Ordinary Differential Equations
-------------------------------------------

Dymos's `RungeKutta` and solver-based pseudspectral transcriptions
provide the ability to numerically integrate the ODE system it is given.
Used in an optimal control context, these provide a shooting method in 
which each iteration provides a physically viable trajectory.

Pseudospectral Methods
----------------------

dymos currently supports the Radau Pseudospectral Method and high-order
Gauss-Lobatto transcriptions.  These implicit techniques rely on the
optimizer to impose "defect" constraints which enforce the physical
accuracy of the resulting trajectories.  To verify the physical
accuracy of the solutions, Dymos can explicitly integrate them using
variable-step methods.


Solving Optimal Control Problems
--------------------------------

dymos uses the concept of *phases* to support optimal control of dynamical systems.
Users connect one or more phases to construct trajectories.
Each phase can have its own:

- Optimal Control Transcription (Gauss-Lobatto, Radau Pseudospectral, or RungeKutta)
- Equations of motion
- Boundary and path constraints

dymos Phases and Trajectories are ultimately just OpenMDAO Groups that can exist in
a problem along with numerous other models, allowing for the simultaneous
optimization of systems and dynamics.
