shader.setFloat(0, size.width);
shader.setFloat(1, size.height);

// Waktu
shader.setFloat(2, time);

// Globe bergerak searah jarum jam
shader.setFloat(3, time * 0.72);

// Atmosfer dan texture bergerak berlawanan
shader.setFloat(4, -time * 1.0);

// Intensitas glow
shader.setFloat(5, 3.0);

shader.setImageSampler(
  0,
  textTexture,
);
