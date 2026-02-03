/**
 * Get a stock image URL for a location using Unsplash
 * Falls back to a default travel image if location parsing fails
 */
export function getLocationImage(location: string): string {
  // Extract city and country from location string
  // Format: "City, Country" or "City Country" or just "City"
  const parts = location.split(',').map(part => part.trim());
  const city = parts[0] || location;
  const country = parts[1] || '';
  
  // Build search query - prefer city, fallback to country
  const query = country ? `${city}, ${country}` : city;
  
  // Encode for URL
  const encodedQuery = encodeURIComponent(query);
  
  // Use Unsplash Source API for consistent, high-quality images
  // w=800 for good quality, fit=crop for consistent aspect ratio
  return `https://source.unsplash.com/800x600/?${encodedQuery},travel`;
}


