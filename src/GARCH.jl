# Julia GARCH package
# Copyright 2013 Andrey Kolev
# Distributed under MIT license (see LICENSE.md)

module GARCH

using NLopt, Distributions

export garchFit, garchPkgTest, predict

include("tests.jl")

type GarchFit
  data::Vector
  params::Vector
  llh::Float64
  status::Symbol
  converged::Bool
  sigma::Vector
end

function Base.show(io::IO ,fit::GarchFit)
  @printf io "Fitted garch model\n"
  @printf io " * Coefficient(s): \tomega \t\talpha \t\tbeta\n"
  @printf io " * \t\t\t%f\t%f\t%f\n" fit.params[1] fit.params[2] fit.params[3]
  @printf io " * Log Likelihood: %f\n" fit.llh
  @printf io " * Converged: %s\n" fit.converged
  @printf io " * Optimizer status: %s\n\n" fit.status
  println(io," * Standardised Residuals Tests:")
  println(io," * \t\t\t\tStatistic\tp-Value")
  jbstat,jbp = jbtest(fit.data./fit.sigma);
  @printf io " * Jarque-Bera Test\t\U1D6D8\u00B2\t%.6f\t%.6f\n" jbstat jbp
end

function predict(fit::GarchFit)
 omega, alpha, beta = fit.params;
 rets = fit.data
 rets2   = rets.^2;
 T = length(rets); 
 ht    = zeros(T);
 ht[1] = sum(rets2)/T;
 for i=2:T
    ht[i] = omega + alpha*rets2[i-1] + beta * ht[i-1];
 end
 sqrt(omega + alpha*rets2[end] + beta*ht[end]);
end

function garchFit(data::Vector)
  rets = data
  rets2   = rets.^2;
  T = length(rets); 
  ht = zeros(T);
  function garchLike(x::Vector, grad::Vector)
    omega,alpha,beta = x;
    ht[1] = sum(rets2)/T;
    for i=2:T
      ht[i] = omega + alpha*rets2[i-1] + beta * ht[i-1];
    end
    sum( log(ht) + (rets./sqrt(ht)).^2 );
  end
  opt = Opt(:LN_SBPLX,3)
  lower_bounds!(opt,[1e-10, 0.0, 0.0])
  upper_bounds!(opt,[1; 0.3; 0.99])
  min_objective!(opt, garchLike)
  (minf,minx,ret) = optimize(opt, [1e-5, 0.09, 0.89])
  converged = minx[1]>0 && all(minx[2:3].>=0) && sum(minx[2:3])<1.0
  out = GarchFit(data, minx, -0.5*(T-1)*log(2*pi)-0.5*minf, ret, converged, sqrt(ht))
end

function garchPkgTest()
  println("Running GARCH package test...")
  try
    include(Pkg.dir("GARCH", "test","GARCHtest.jl"))
    println("All tests passed!")
  catch err
    throw(err)
  end
end

end  #module