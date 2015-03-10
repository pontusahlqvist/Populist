import os
import sys
import optparse

optparser = optparse.OptionParser()
optparser.add_option("--sigma-min", dest = "sigma_min", type = float, default = 0.01)
optparser.add_option("--sigma-max", dest = "sigma_max", type = float, default = 0.03)
(options, args) = optparser.parse_args(sys.argv)

smin = options.sigma_min
smax = options.sigma_max

lambda_min = 1/smax**2
lambda_max = 1/smin**2
lambda_star = 0.5*(lambda_min + lambda_max)
delta_lambda = 0.5*(lambda_max - lambda_min)

alpha0 = lambda_star**2/delta_lambda**2
beta0 = lambda_star/delta_lambda**2

print "You should chose alpha0 = " + str(alpha0) + " and beta0 = " + str(beta0)
