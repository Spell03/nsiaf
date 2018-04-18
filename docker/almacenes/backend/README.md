# Backend del sistema NSIAF

`Antes de iniciar un contenedor de esta imagen debe estar funcionando primero el` [contenedor de la base de datos](../db/README.md)

* Crear la imagen de nsiaf

```sh
docker build -t nsiaf:1.0.0 -f ./Dockerfile .
```

* Iniciar un contenedor del subsistema

```sh
docker run --name nsiaf-backend --link nsiaf-db --env-file ../.env -p 8888:3000 -d nsiaf:1.0.0
```

* El volumen que expone el contenedor es `/opt/nsiaf/log`

* El puerto que expone el contenedor es `3000` que en este caso es redireccionado al puerto `8888`.