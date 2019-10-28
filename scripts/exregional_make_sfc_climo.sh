#!/bin/bash

#
#-----------------------------------------------------------------------
#
# Source the variable definitions script and the function definitions
# file.
#
#-----------------------------------------------------------------------
#
. ${SCRIPT_VAR_DEFNS_FP}
. $USHDIR/source_funcs.sh
#
#-----------------------------------------------------------------------
#
# Save current shell options (in a global array).  Then set new options
# for this script/function.
#
#-----------------------------------------------------------------------
#
{ save_shell_opts; set -u +x; } > /dev/null 2>&1
#
#-----------------------------------------------------------------------
#
# Get the name of this script as well as the directory in which it is 
# located.
#
#-----------------------------------------------------------------------
#
script_path=$( readlink -f "${BASH_SOURCE[0]}" )
script_name=$( basename "${script_path}" )
script_dir=$( dirname "${script_path}" )
print_info_msg "
========================================================================
Entering script:  \"${script_path}\"

This is the ex-script for the task that generates surface fields from
climatology.
========================================================================"
#
#-----------------------------------------------------------------------
#
# Specify the set of valid argument names for this script/function.  
# Then process the arguments provided to this script/function (which 
# should consist of a set of name-value pairs of the form arg1="value1",
# etc).
#
#-----------------------------------------------------------------------
#
valid_args=( "workdir" )
process_args valid_args "$@"

# If VERBOSE is set to TRUE, print out what each valid argument has been
# set to.
if [ "$VERBOSE" = "TRUE" ]; then
  num_valid_args="${#valid_args[@]}"
  print_info_msg "
The arguments to script/function \"${script_name}\" have been set as 
follows:
"
  for (( i=0; i<${num_valid_args}; i++ )); do
    line=$( declare -p "${valid_args[$i]}" )
    printf "  $line\n"
  done
fi
#
#-----------------------------------------------------------------------
#
# Are these machine dependent??
#
#-----------------------------------------------------------------------
#
ulimit -s unlimited
#
#-----------------------------------------------------------------------
#
# Change location to the temporary directory.
#
#-----------------------------------------------------------------------
#
cd_vrfy $workdir
#
#-----------------------------------------------------------------------
#
# Create the namelist that the sfc_climo_gen code will read in.
#
# Question: Should this instead be created from a template file?
#
#-----------------------------------------------------------------------
#
cat << EOF > ./fort.41
&config
input_facsf_file="${SFC_CLIMO_INPUT_DIR}/facsf.1.0.nc"
input_substrate_temperature_file="${SFC_CLIMO_INPUT_DIR}/substrate_temperature.2.6x1.5.nc"
input_maximum_snow_albedo_file="${SFC_CLIMO_INPUT_DIR}/maximum_snow_albedo.0.05.nc"
input_snowfree_albedo_file="${SFC_CLIMO_INPUT_DIR}/snowfree_albedo.4comp.0.05.nc"
input_slope_type_file="${SFC_CLIMO_INPUT_DIR}/slope_type.1.0.nc"
input_soil_type_file="${SFC_CLIMO_INPUT_DIR}/soil_type.statsgo.0.05.nc"
input_vegetation_type_file="${SFC_CLIMO_INPUT_DIR}/vegetation_type.igbp.0.05.nc"
input_vegetation_greenness_file="${SFC_CLIMO_INPUT_DIR}/vegetation_greenness.0.144.nc"
mosaic_file_mdl="${FIXsar}/${CRES}_mosaic.nc"
orog_dir_mdl="${FIXsar}"
orog_files_mdl=${CRES}_oro_data.tile${TILE_RGNL}.halo${nh4_T7}.nc
halo=${nh4_T7}
maximum_snow_albedo_method="bilinear"
snowfree_albedo_method="bilinear"
vegetation_greenness_method="bilinear"
/
EOF
#
#-----------------------------------------------------------------------
#
# Set the run machine-dependent run command.
#
#-----------------------------------------------------------------------
#
case $MACHINE in

"WCOSS_C")
# This could be wrong.  Just a guess since I don't have access to this machine.
  APRUN_SFC=${APRUN_SFC:-"aprun -j 1 -n 6 -N 6"}
  ;;

"WCOSS")
# This could be wrong.  Just a guess since I don't have access to this machine.
  APRUN_SFC=${APRUN_SFC:-"aprun -j 1 -n 6 -N 6"}
  ;;

"THEIA")
# Need to load intel/15.1.133.  This and all other module loads should go into a module file.
  module load intel/15.1.133
  module list
  APRUN_SFC="mpirun -np ${SLURM_NTASKS}"
  ;;

"HERA")
  module purge
  module load intel/18.0.5.274
  module load impi/2018.0.4
  module load netcdf/4.6.1
  #module use /scratch1/NCEPDEV/nems/emc.nemspara/soft/modulefiles
  export NCEPLIBS=/scratch1/NCEPDEV/global/gwv/l819/lib
  module use -a $NCEPLIBS/modulefiles
  module load esmflocal/8_0_48b.netcdf47
  #module load esmf/7.1.0r
  module list
  APRUN_SFC="srun"
  ;;

*)
  print_err_msg_exit "\
Run command has not been specified for this machine:
  MACHINE = \"$MACHINE\"
  APRUN_SFC = \"$APRUN_SFC\""
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Run the code.
#
#-----------------------------------------------------------------------
#
$APRUN_SFC ${EXECDIR}/sfc_climo_gen || print_err_msg_exit "\
Call to executable that generates surface climatology files returned 
with nonzero exit code."
#
#-----------------------------------------------------------------------
#
# Move output files out of the temporary directory.
#
#-----------------------------------------------------------------------
#
case "$gtype" in

#
# Consider, global, stetched, and nested grids.
#
"global" | "stretch" | "nested")
#
# Move all files ending with ".nc" to the SFC_CLIMO_DIR directory.
# In the process, rename them so that the file names start with the C-
# resolution (followed by an underscore).
#
  for fn in *.nc; do
    if [[ -f $fn ]]; then
      mv_vrfy $fn ${SFC_CLIMO_DIR}/${CRES}_${fn}
    fi
  done
  ;;

#
# Consider regional grids.
#
"regional")
#
# Move all files ending with ".halo.nc" (which are the files for a grid
# that includes the specified non-zero-width halo) to the WORKDIR_SFC_-
# CLIMO directory.  In the process, rename them so that the file names
# start with the C-resolution (followed by a dot) and contain the (non-
# zero) halo width (in units of number of grid cells).
#
  for fn in *.halo.nc; do
    if [ -f $fn ]; then
      bn="${fn%.halo.nc}"
      mv_vrfy $fn ${SFC_CLIMO_DIR}/${CRES}.${bn}.halo${nh4_T7}.nc
    fi
  done
#
# Move all remaining files ending with ".nc" (which are the files for a
# grid that doesn't include a halo) to the SFC_CLIMO_DIR directory.  
# In the process, rename them so that the file names start with the C-
# resolution (followed by a dot) and contain the string "halo0" to indi-
# cate that the grids in these files do not contain a halo.
#
  for fn in *.nc; do
    if [ -f $fn ]; then
      bn="${fn%.nc}"
      mv_vrfy $fn ${SFC_CLIMO_DIR}/${CRES}.${bn}.halo${nh0_T7}.nc
    fi
  done
  ;;

esac
#
#-----------------------------------------------------------------------
#
# Can these be moved to stage_static if this script is called before
# stage_static.sh????
# These have been moved.  Can delete the following after testing.
#
#-----------------------------------------------------------------------
#
$USHDIR/link_fix.sh \
  verbose="FALSE" \
  script_var_defns_fp="${SCRIPT_VAR_DEFNS_FP}" \
  file_group="sfc_climo" || \
print_err_msg_exit "\
Call to script to create links to surface climatology files failed."
#
#-----------------------------------------------------------------------
#
# GSK 20190430:
# This is to make rocoto aware that the make_sfc_climo task has completed
# (so that other tasks can be launched).  This should be done through 
# rocoto's dependencies, but not sure how to do it yet.
#
#-----------------------------------------------------------------------
#
cd_vrfy $EXPTDIR
touch "make_sfc_climo_files_task_complete.txt"
#
#-----------------------------------------------------------------------
#
# Print message indicating successful completion of script.
#
#-----------------------------------------------------------------------
#
print_info_msg "
========================================================================
All surface climatology files generated successfully!!!

Exiting script:  \"${script_path}\"
========================================================================"
#
#-----------------------------------------------------------------------
#
# Restore the shell options saved at the beginning of this script/func-
# tion.
#
#-----------------------------------------------------------------------
#
{ restore_shell_opts; } > /dev/null 2>&1
