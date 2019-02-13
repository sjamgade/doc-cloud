#!/bin/bash

set -e

# Author: Thomas Bechtold <tbechtold@suse.com>
# Author: Jeremy Moffitt <jmoffitt@suse.com>
# License: Apache-2.0

# List of project for running the doc generation
#: ${PROJECTS:="aodh barbican ceilometer cinder designate glance heat horizon keystone magnum manila murano neutron neutron-fwaas neutron-lbaas neutron-vpnaas octavia nova sahara"}
: ${PROJECTS:="keystone manila"}
# ironic docs fail on the first build, causing the sript to stop, should
# be added back once error is resolved

# swift docs don't build successfully on stable/rocky and should be added
# back once https://review.openstack.org/636595 has been resolved

# keystone doc builds require openldap2-devel , if the build fails on keystone
# zypper install openldap2-devel and try again

# directory where the OpenStack git repositories are in
: ${OPENSTACK_REPO_DIR:=${PWD}/devel/openstack}
# branch to use when creating the doc
: ${OPENSTACK_REPO_BRANCH:=stable/rocky}
# extra tox options (eg. -r)
: ${TOX_OPTS:=""}
# the base output directory for the html files
: ${OUTPUT_DIR:=${PWD}/devel/openstack-docs-html}


if [ ! -d "${OPENSTACK_REPO_DIR}" ]; then
    mkdir -p ${OPENSTACK_REPO_DIR}
fi

if [ ! -d "${OUTPUT_DIR}" ]; then
    mkdir -p ${OUTPUT_DIR}
fi
        
for project in $PROJECTS; do
    echo "##### ${project}"
    (
        if [ ! -d "${OPENSTACK_REPO_DIR}/${project}" ]; then
            cd ${OPENSTACK_REPO_DIR}
            echo "### Cloning git repo"
            git clone https://git.openstack.org/openstack/${project}
        fi
        cd ${OPENSTACK_REPO_DIR}/${project}
        git checkout ${OPENSTACK_REPO_BRANCH}
        echo "### Clear out any changes that may have come from previous failed runs"
        git checkout doc/source/conf.py
        echo "### Updating conf.py"
        sed -i "s/html_theme = 'openstackdocs'/html_theme = 'suse_sphinx_theme'/g" doc/source/conf.py
        if [ -f doc/requirements.txt ]; then
            echo "### Updating doc/requirements.txt"
            git checkout doc/requirements.txt
            grep -q -x -F 'suse_sphinx_theme' doc/requirements.txt || echo '-e git+https://github.com/SUSE/suse-sphinx-theme.git@master#egg=suse_sphinx_theme' >> doc/requirements.txt
        else
            if [ -f test-requirements.txt ]; then
               echo "### Updating test-requirements.txt"
               git checkout test-requirements.txt
               grep -q -x -F 'suse_sphinx_theme' test-requirements.txt || echo '-e git+https://github.com/SUSE/suse-sphinx-theme.git@master#egg=suse_sphinx_theme' >> test-requirements.txt
            fi
        fi
        echo "### Build the theme'd docs"
        tox ${TOX_OPTS} -e docs
        if [ ! -d "${OUTPUT_DIR}/${project}" ]; then
            echo "### Creating output folder"
            mkdir -p ${OUTPUT_DIR}/${project}
        fi
        echo "### Copying docs to output folder"
        if [ -d "${OPENSTACK_REPO_DIR}/${project}/doc/build/html" ]; then
          cp -r ${OPENSTACK_REPO_DIR}/${project}/doc/build/html/* ${OUTPUT_DIR}/${project}
        else
          if [ -d "${OPENSTACK_REPO_DIR}/${project}/doc" ]; then
            echo "### html folder not found, copying doc/build folder for project ${project}"
            cp -r ${OPENSTACK_REPO_DIR}/${project}/doc/build/* ${OUTPUT_DIR}/${project}
          else
            echo "### No doc build found for project ${project}"
          fi
        fi
    )
done

echo "###################################################################"
echo "Your rst html files for the different projects are in ${OUTPUT_DIR}"
echo "###################################################################"
