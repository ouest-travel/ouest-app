import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { X, Plane, MapPin, Users, DollarSign, Calendar as CalendarIcon, Sparkles, Dice6, Plus, Share2 } from "lucide-react";
import { Button } from "./ui/button";
import { Input } from "./ui/input";
import { Calendar } from "./ui/calendar";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/select";
import { Switch } from "./ui/switch";
import { Avatar, AvatarFallback, AvatarImage } from "./ui/avatar";

interface BookTripFlowProps {
  onClose: () => void;
}

interface TripData {
  name: string;
  destination: string;
  destinationCountry: string;
  budget: string;
  currency: string;
  splitEvenly: boolean;
  startDate: Date | undefined;
  endDate: Date | undefined;
  members: Array<{ name: string; avatar?: string }>;
}

const popularDestinations = [
  { city: "Paris", country: "France", flag: "🇫🇷" },
  { city: "Tokyo", country: "Japan", flag: "🇯🇵" },
  { city: "Lisbon", country: "Portugal", flag: "🇵🇹" },
  { city: "New York", country: "USA", flag: "🇺🇸" },
  { city: "Bali", country: "Indonesia", flag: "🇮🇩" },
  { city: "Barcelona", country: "Spain", flag: "🇪🇸" },
];

const tripNameSuggestions = [
  "Girls Trip to Paradise",
  "Bros Weekend Escape",
  "Family Adventure 2025",
  "Squad Goals Vacation",
  "Wanderlust Chronicles",
  "The Great Escape",
];

export function BookTripFlow({ onClose }: BookTripFlowProps) {
  const [step, setStep] = useState(1);
  const [tripData, setTripData] = useState<TripData>({
    name: "",
    destination: "",
    destinationCountry: "",
    budget: "",
    currency: "USD",
    splitEvenly: true,
    startDate: undefined,
    endDate: undefined,
    members: [{ name: "You", avatar: "" }],
  });

  const totalSteps = 6;

  const nextStep = () => {
    if (step < totalSteps) {
      setStep(step + 1);
    }
  };

  const prevStep = () => {
    if (step > 1) {
      setStep(step - 1);
    }
  };

  const generateRandomName = () => {
    const randomName = tripNameSuggestions[Math.floor(Math.random() * tripNameSuggestions.length)];
    setTripData({ ...tripData, name: randomName });
  };

  const selectDestination = (city: string, country: string, flag: string) => {
    setTripData({ ...tripData, destination: city, destinationCountry: `${country} ${flag}` });
  };

  const addMember = () => {
    const newMember = { name: `Friend ${tripData.members.length}`, avatar: "" };
    setTripData({ ...tripData, members: [...tripData.members, newMember] });
  };

  const getDayCount = () => {
    if (tripData.startDate && tripData.endDate) {
      const diff = Math.ceil((tripData.endDate.getTime() - tripData.startDate.getTime()) / (1000 * 60 * 60 * 24));
      return diff;
    }
    return 0;
  };

  const formatDate = (date: Date | undefined) => {
    if (!date) return "";
    return date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  };

  const pageVariants = {
    initial: { opacity: 0, x: 50 },
    animate: { opacity: 1, x: 0 },
    exit: { opacity: 0, x: -50 },
  };

  return (
    <div className="fixed inset-0 bg-white z-50 overflow-y-auto">
      {/* Header with Progress */}
      <div className="sticky top-0 bg-white border-b border-gray-100 z-10">
        <div className="max-w-2xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between mb-4">
            <Button variant="ghost" size="sm" onClick={step === 1 ? onClose : prevStep}>
              <X className="w-5 h-5" />
            </Button>
            <div className="text-center">
              <p className="text-sm text-gray-500">Step {step} of {totalSteps}</p>
            </div>
            <div className="w-10" /> {/* Spacer */}
          </div>

          {/* Progress Bar */}
          <div className="h-1 bg-gray-100 rounded-full overflow-hidden">
            <motion.div
              className="h-full rounded-full"
              style={{
                background: "linear-gradient(90deg, #667eea 0%, #764ba2 25%, #f093fb 50%, #f5576c 75%, #4facfe 100%)",
              }}
              initial={{ width: 0 }}
              animate={{ width: `${(step / totalSteps) * 100}%` }}
              transition={{ duration: 0.5, ease: "easeOut" }}
            />
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="max-w-2xl mx-auto px-4 py-8">
        <AnimatePresence mode="wait">
          {step === 1 && (
            <motion.div
              key="step1"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3 }}
              className="flex flex-col items-center justify-center min-h-[60vh]"
            >
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                className="mb-8"
              >
                <div className="w-24 h-24 rounded-full bg-gradient-to-br from-blue-400 via-purple-400 to-pink-400 flex items-center justify-center">
                  <Plane className="w-12 h-12 text-white" />
                </div>
              </motion.div>

              <h1 className="text-center mb-3">Plan Your Next Adventure</h1>
              <p className="text-center text-gray-600 mb-8 max-w-md">
                Create a trip to start planning with friends.
              </p>

              <Button
                onClick={nextStep}
                className="bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90 text-white px-8 py-6 rounded-2xl shadow-lg"
              >
                <Sparkles className="w-5 h-5 mr-2" />
                Book a Trip
              </Button>
            </motion.div>
          )}

          {step === 2 && (
            <motion.div
              key="step2"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3 }}
            >
              <h1 className="mb-2">What should we call this trip?</h1>
              <p className="text-gray-600 mb-8">Give your trip a name everyone will remember.</p>

              <div className="space-y-6">
                <div className="relative">
                  <Input
                    value={tripData.name}
                    onChange={(e) => setTripData({ ...tripData, name: e.target.value })}
                    placeholder="Girls Trip to Lisbon"
                    maxLength={40}
                    className="text-lg py-6 px-4 rounded-xl border-2 border-gray-200 focus:border-purple-400 transition-all"
                    style={{
                      boxShadow: tripData.name ? "0 0 0 3px rgba(139, 92, 246, 0.1)" : "none",
                    }}
                  />
                  <div className="flex items-center justify-between mt-2">
                    <span className="text-sm text-gray-500">{tripData.name.length}/40</span>
                    <Button variant="ghost" size="sm" onClick={generateRandomName}>
                      <Dice6 className="w-4 h-4 mr-1" />
                      Surprise me
                    </Button>
                  </div>
                </div>

                <Button
                  onClick={nextStep}
                  disabled={!tripData.name}
                  className="w-full py-6 rounded-xl bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90 disabled:opacity-50"
                >
                  Next →
                </Button>
              </div>
            </motion.div>
          )}

          {step === 3 && (
            <motion.div
              key="step3"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3 }}
            >
              <h1 className="mb-2">Where are you heading?</h1>
              <p className="text-gray-600 mb-8">Search for a city or country.</p>

              <div className="space-y-6">
                <div className="relative">
                  <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <Input
                    value={tripData.destination}
                    onChange={(e) => setTripData({ ...tripData, destination: e.target.value })}
                    placeholder="Search destination..."
                    className="text-lg py-6 pl-12 pr-4 rounded-xl border-2 border-gray-200 focus:border-purple-400"
                  />
                </div>

                <div className="space-y-3">
                  <p className="text-sm text-gray-500">Popular Destinations</p>
                  <div className="grid grid-cols-2 gap-3">
                    {popularDestinations.map((dest) => (
                      <motion.button
                        key={dest.city}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => selectDestination(dest.city, dest.country, dest.flag)}
                        className={`p-4 rounded-xl border-2 transition-all text-left ${
                          tripData.destination === dest.city
                            ? "border-purple-400 bg-purple-50"
                            : "border-gray-200 hover:border-gray-300"
                        }`}
                      >
                        <div className="text-2xl mb-1">{dest.flag}</div>
                        <div>{dest.city}</div>
                        <div className="text-sm text-gray-500">{dest.country}</div>
                      </motion.button>
                    ))}
                  </div>
                </div>

                <Button
                  onClick={nextStep}
                  disabled={!tripData.destination}
                  className="w-full py-6 rounded-xl bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90 disabled:opacity-50"
                >
                  Next →
                </Button>
              </div>
            </motion.div>
          )}

          {step === 4 && (
            <motion.div
              key="step4"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3 }}
            >
              <h1 className="mb-2">Who's coming along?</h1>
              <p className="text-gray-600 mb-8">Invite your travel crew to join the plan.</p>

              <div className="space-y-6">
                <div className="flex flex-wrap gap-3 items-center">
                  {tripData.members.map((member, idx) => (
                    <motion.div
                      key={idx}
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      className="flex flex-col items-center gap-2"
                    >
                      <Avatar className="w-16 h-16 border-2 border-purple-200">
                        <AvatarFallback className="bg-gradient-to-br from-blue-400 to-purple-400 text-white">
                          {member.name.substring(0, 2).toUpperCase()}
                        </AvatarFallback>
                      </Avatar>
                      <span className="text-sm text-gray-600">{member.name}</span>
                    </motion.div>
                  ))}

                  <motion.button
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={addMember}
                    className="flex flex-col items-center gap-2"
                  >
                    <div className="w-16 h-16 rounded-full border-2 border-dashed border-gray-300 flex items-center justify-center hover:border-purple-400 transition-colors">
                      <Plus className="w-6 h-6 text-gray-400" />
                    </div>
                    <span className="text-sm text-gray-500">Add</span>
                  </motion.button>
                </div>

                <div className="bg-purple-50 rounded-xl p-4 flex items-start gap-3">
                  <Switch
                    checked={true}
                    className="mt-1"
                  />
                  <div>
                    <p className="text-sm">Allow invited friends to edit itinerary</p>
                    <p className="text-xs text-gray-500 mt-1">
                      Once your friends join, you can start chatting and planning together.
                    </p>
                  </div>
                </div>

                <Button
                  onClick={nextStep}
                  className="w-full py-6 rounded-xl bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90"
                >
                  Next →
                </Button>
              </div>
            </motion.div>
          )}

          {step === 5 && (
            <motion.div
              key="step5"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3 }}
            >
              <h1 className="mb-2">Set a budget (optional)</h1>
              <p className="text-gray-600 mb-8">We'll help you stay on track during the trip.</p>

              <div className="space-y-6">
                <div className="space-y-3">
                  <label className="text-sm text-gray-600">Currency</label>
                  <Select value={tripData.currency} onValueChange={(val) => setTripData({ ...tripData, currency: val })}>
                    <SelectTrigger className="rounded-xl py-6">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="USD">🇺🇸 USD - US Dollar</SelectItem>
                      <SelectItem value="EUR">🇪🇺 EUR - Euro</SelectItem>
                      <SelectItem value="GBP">🇬🇧 GBP - British Pound</SelectItem>
                      <SelectItem value="JPY">🇯🇵 JPY - Japanese Yen</SelectItem>
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-3">
                  <label className="text-sm text-gray-600">Total Trip Budget</label>
                  <div className="relative">
                    <DollarSign className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                    <Input
                      type="number"
                      value={tripData.budget}
                      onChange={(e) => setTripData({ ...tripData, budget: e.target.value })}
                      placeholder="2000"
                      className="text-lg py-6 pl-12 pr-4 rounded-xl border-2 border-gray-200 focus:border-purple-400"
                    />
                  </div>
                  <p className="text-xs text-gray-500">You can always change this later.</p>
                </div>

                <div className="bg-blue-50 rounded-xl p-4 flex items-start gap-3">
                  <Switch
                    checked={tripData.splitEvenly}
                    onCheckedChange={(val) => setTripData({ ...tripData, splitEvenly: val })}
                    className="mt-1"
                  />
                  <div>
                    <p className="text-sm">Split expenses evenly by default</p>
                    <p className="text-xs text-gray-500 mt-1">
                      All trip expenses will be split equally among members.
                    </p>
                  </div>
                </div>

                <div className="flex gap-3">
                  <Button
                    onClick={nextStep}
                    variant="outline"
                    className="flex-1 py-6 rounded-xl border-2"
                  >
                    Skip
                  </Button>
                  <Button
                    onClick={nextStep}
                    className="flex-1 py-6 rounded-xl bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90"
                  >
                    Next →
                  </Button>
                </div>
              </div>
            </motion.div>
          )}

          {step === 6 && (
            <motion.div
              key="step6"
              variants={pageVariants}
              initial="initial"
              animate="animate"
              exit="exit"
              transition={{ duration: 0.3 }}
            >
              <h1 className="mb-2">When are you going?</h1>
              <p className="text-gray-600 mb-8">Select your start and end dates.</p>

              <div className="space-y-6">
                <div className="bg-white rounded-xl border-2 border-gray-200 p-4">
                  <Calendar
                    mode="range"
                    selected={{
                      from: tripData.startDate,
                      to: tripData.endDate,
                    }}
                    onSelect={(range) => {
                      setTripData({
                        ...tripData,
                        startDate: range?.from,
                        endDate: range?.to,
                      });
                    }}
                    className="rounded-lg"
                  />
                </div>

                {tripData.startDate && tripData.endDate && (
                  <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl p-4 text-center"
                  >
                    <CalendarIcon className="w-5 h-5 mx-auto mb-2 text-purple-600" />
                    <p>
                      <span>{getDayCount()} days</span> in <span>{tripData.destination}</span>
                    </p>
                    <p className="text-sm text-gray-600 mt-1">
                      {formatDate(tripData.startDate)} – {formatDate(tripData.endDate)}
                    </p>
                  </motion.div>
                )}

                <Button
                  onClick={nextStep}
                  disabled={!tripData.startDate || !tripData.endDate}
                  className="w-full py-6 rounded-xl bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90 disabled:opacity-50"
                >
                  Create Trip →
                </Button>
              </div>
            </motion.div>
          )}

          {step === 7 && (
            <motion.div
              key="step7"
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.5 }}
            >
              <div className="text-center mb-8">
                <motion.div
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
                  className="inline-block mb-4"
                >
                  <div className="text-6xl">✈️</div>
                </motion.div>
                <h1 className="mb-2">Your Trip is Ready!</h1>
                <p className="text-gray-600">Here's a quick look before we start planning.</p>
              </div>

              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 }}
                className="bg-gradient-to-br from-blue-50 via-purple-50 to-pink-50 rounded-2xl p-6 space-y-4 mb-6 border-2 border-purple-100"
              >
                <div>
                  <p className="text-sm text-gray-500 mb-1">Trip Name</p>
                  <h2>{tripData.name}</h2>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="text-sm text-gray-500 mb-1">Destination</p>
                    <p>
                      {tripData.destination}
                      {tripData.destinationCountry && `, ${tripData.destinationCountry}`}
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-500 mb-1">Duration</p>
                    <p>{getDayCount()} days</p>
                  </div>
                </div>

                <div>
                  <p className="text-sm text-gray-500 mb-1">Dates</p>
                  <p>
                    {formatDate(tripData.startDate)} – {formatDate(tripData.endDate)}
                  </p>
                </div>

                {tripData.budget && (
                  <div>
                    <p className="text-sm text-gray-500 mb-1">Budget</p>
                    <p>
                      {tripData.currency} ${tripData.budget}
                      {tripData.splitEvenly && " (split evenly)"}
                    </p>
                  </div>
                )}

                <div>
                  <p className="text-sm text-gray-500 mb-2">Members</p>
                  <div className="flex items-center gap-2">
                    {tripData.members.map((member, idx) => (
                      <Avatar key={idx} className="w-10 h-10 border-2 border-white">
                        <AvatarFallback className="bg-gradient-to-br from-blue-400 to-purple-400 text-white text-xs">
                          {member.name.substring(0, 2).toUpperCase()}
                        </AvatarFallback>
                      </Avatar>
                    ))}
                    <button className="w-10 h-10 rounded-full border-2 border-dashed border-gray-300 flex items-center justify-center hover:border-purple-400 transition-colors">
                      <Plus className="w-4 h-4 text-gray-400" />
                    </button>
                  </div>
                </div>
              </motion.div>

              <div className="space-y-3">
                <Button
                  onClick={onClose}
                  className="w-full py-6 rounded-xl bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500 hover:opacity-90"
                >
                  Start Planning
                </Button>
                <Button variant="outline" className="w-full py-6 rounded-xl border-2">
                  <Share2 className="w-4 h-4 mr-2" />
                  Share Invite Link
                </Button>
              </div>

              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.5 }}
                className="mt-8 text-center"
              >
                <p className="text-sm text-gray-500">
                  🎉 Congratulations! Your adventure begins here.
                </p>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
