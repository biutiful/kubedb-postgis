# Running Postgres with PostGIS for KubeDB
[KubeDB](https://kubedb.com/) runs PostgreSQL database on Kubernetes. To deploy PostgreSQL database, KubeDB uses the docker image which is specified in a Kubernetes `PostgresVersion` resource.
KubeDB provides several `PostgresVersion` resources with docker images. But these docker images don't support PostGIS.
Here builds the PostgreSQL docker images with PostGIS based on the KubeDB provided docker images. The used Dockerfile is based on the work of [mdillon/postgis](https://github.com/appropriate/docker-postgis).

In addition, a yaml file called `postgresversion.yaml` is created for each docker image. The file defines the `PostgresVersion` resource, and can be applied directly on your Kubernetes cluster. 

## Usage
```bash
# assuming taht the kubedb and kubedb-catalog have been installed on your kubernetes cluster
$ ./build-all.sh \
    --docker-registry=<docker-registry> \
    --image=<docker-image-name> \
    --postgres-versions=10.6-v2,11.1-v2,11.2 \
    --postgis-version=2.5.2
# push docker image to registery, and create PostgresVersion resource
$ docker push <docker-registry>/<docker-image-name>:11.2
$ kubectl create -f 11.2/postgresversion.yaml

# or just build the docker image without kubernetes cluster
$ ./build.sh \
    --docker-registry=<docker-registry> \
    --image=<docker-image-name> \
    --postgres-version=11.2 \
    --postgis-version=2.5.2
    --target-path=11.2
```

## Cautions
* The `Dockerfile` that is generated from `Dockerfile.template` builds the PostGIS from the source code. It requires several packages. For alpine, some packages are maintained in the edge repository. The edge contains the latest build of all available packages. These packages may not work on old alpine versions.

  | Postgres Version      | Alpine Version | Build Status                  |
  | :-------------------: | :------------: | :---------------------------: |
  | kubedb/postgres:9.6   | alpine 3.5.2   | :negative_squared_cross_mark: |
  | kubedb/postgres:10.2  | alpine 3.7.0   | :negative_squared_cross_mark: |
  | kubedb/postgres:10.6  | alpine 3.9.0   | :white_check_mark:            |
  | kubedb/postgres:11.1  | alpine 3.9.0   | :white_check_mark:            |
  | kubedb/postgres:11.2  | alpine 3.9.3   | :white_check_mark:            |

* The `10.6-v2`, `11.1-v2`, `11.2` folders are created automatically by running `build-all.sh` command, they can be ignored.