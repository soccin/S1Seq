# Publication title: A global view of meiotic double-strand break end resection
# Publication authors: Eleni P. Mimitou (1), Shintaro Yamada (1) and Scott Keeney (1, 2)
# Affiliation (1): Molecular Biology Program, Memorial Sloan Kettering Cancer Center, New York, NY, 10065.
# Affiliation (2): Howard Hughes Medical Institute, Memorial Sloan Kettering Cancer Center, New York, NY, 10065.
#
# Script authors: Shintaro Yamada
# Contact: Scott Keeney <s-keeney@ski.mskcc.org>
#
# Aim: Exo1 resection speed analysis
# Description: Generate a matrix of simulated resection endpoint (Sample x Simulation time)

##########
# Source
##########
# Require mean hotspot profiles
# of Exo1-entry site (exo1-nd profile)
# and of Exo1 run length (shifted geometoric)
load("Mre11-dependent.clipping.position.Rdata") # profile.M: exo1-nd resection endpoint profile

kGeom.shift <- 160 # Shift of geometric distribution (bp)
kGeom.prob <- 0.00382 # Parameter of geometric distribution

##########
# Function
##########
Calculate.d <- function(t, v, tau, mu, eps){
  # Calculate Resection endpoint distance d
  #
  # Args:
  #   t: time in meiosis (min)
  #   v: Exo1 speed (bp / min)
  #   tau: DSB formation time (min)
  #   mu: Mre11-dependent clipping position (bp)
  #   eps: Exo1 run length (bp)
  #
  # Return:
  #   Vector of resection endpoint distance (length: simulation time)
  x <- rep_len(NA, length(t))
  i1 <- which(t > tau)[1]
  if (is.na(i1)) {
    return(x)
  } else {
    t.elapsed <- t[i1:length(t)] - tau  # Time elapsed since DSB formation
    d <- floor(t.elapsed * v + mu) 	    # Resection distance since DSB formation
    d.max <- floor(eps + mu)            # Maximum resection distance
    d[d > d.max] <- d.max               # Stop resection at d.max
    x[i1:length(x)] <- d
    return(x)
  }
}

##########
# Main
##########
# Environmental setting 
set.seed(12345)

# Constant
kSample.size <- 1e6 # Sample size n
kBin.size <- 10
kSim.time <- seq(90, 180, 1) # Simulation time t (min)
kDSB.time.limit <- c(90, 480) # Range of T (min)
kPos <- profile.M$pos # Position to be considered (0, 10, ..., 2000)
kLen.Exo1.run <- seq(0, 2000, kBin.size) # Exo1 run length to be considered (0, 10, ..., 2000)
kExo1.speed <- 40 # Exo1 speed v (kb / hour)

# Variable assignment
## DSB formation time: T = {tau.1, tau.2, ..., tau.n}
sim.T <- rlnorm(n = kSample.size * 1.05, meanlog = 4.5, sdlog = 0.5) + 90
sim.T <- sim.T[kDSB.time.limit[1] <= sim.T & sim.T <= kDSB.time.limit[2]]
sim.T <- sim.T[1:kSample.size]

## Mre11-dependent clipping position: M = {mu.1, mu.2, ..., mu.n}
sim.M <- sample(x = profile.M$pos, size = kSample.size, prob = profile.M$signal, replace = T)

## Exo1 run length: E = {eps.1, eps.2, ..., eps.n}
shifted.geom.p <- c(rep(0, kGeom.shift / kBin.size)
                    , dgeom(0:(length(kLen.Exo1.run) - kGeom.shift / kBin.size - 1) * kBin.size, prob = kGeom.prob))
sim.E <- sample(x = kLen.Exo1.run, size = kSample.size, prob = shifted.geom.p, replace = T)

# Calculation of Resection endpoint distance: D = {d1, d2, ..., dn}
sim.D <- t(sapply(1:kSample.size, function(n) {
  Calculate.d(t = kSim.time, v = kExo1.speed * 1000 / 60, tau = sim.T[n], mu = sim.M[n], eps = sim.E[n])}))
rownames(sim.D) <- 1:kSample.size
colnames(sim.D) <- kSim.time
save(sim.D, file = "Simulated.Resection.endpoints.Rdata")
