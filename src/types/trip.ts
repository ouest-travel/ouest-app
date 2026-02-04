
export interface Trip {
    id: string | number;
    name?: string;
    destination: string;
    dates?: string;
    image?: string;
    budget?: number | string | null;
    travelers?: number;
    coverImage?: string;
    cover_image?: string | null;
    startDate?: Date;
    start_date?: Date | string | null;
    endDate?: Date;
    end_date?: Date | string | null;
    currency?: string;
}
