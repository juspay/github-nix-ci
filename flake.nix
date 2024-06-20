{
  outputs = _: {
    nixci.default = {
      example.dir = ./example;
      dev.dir = ./example;
    };
  };
}
