import { z } from 'zod'

export const env = z
  .object({
    VITE_API_BASE_URL: z
      .url()
      .refine(
        (value) => ['http:', 'https:'].includes(new URL(value).protocol),
        'La API requiere HTTP o HTTPS',
      )
      .default('http://127.0.0.1:8080'),
  })
  .parse({ VITE_API_BASE_URL: import.meta.env.VITE_API_BASE_URL })
