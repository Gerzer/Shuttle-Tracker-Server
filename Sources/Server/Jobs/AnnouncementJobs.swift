import Vapor 
import Fluent
import FluentPostgresDriver // or whichever Fluent driver you're using
import APNS  

// Define a job for sending announcement notifications
struct SendAnnouncementNotificationJob: Job {
    // Define properties needed for the job
    let announcementID: UUID

    // Implement the job execution logic
    func dequeue(_ context: QueueContext, _ task: Task) async throws {
        // Fetch the announcement from the database using the provided announcementID
        guard let announcement = try await Announcement.find(announcementID, on: context.application.db(.psql)).get() else {
            // Handle the case where the announcement could not be found
            context.logger.error("Announcement with ID \(announcementID) not found.")
            return
        }

        // Prepare the APNS notification payload and other settings based on the announcement details
        let interruptionLevel: APNSAlertNotificationInterruptionLevel
        switch announcement.interruptionLevel {
        case .passive:
            interruptionLevel = .passive
        case .active:
            interruptionLevel = .active
        case .timeSensitive:
            interruptionLevel = .timeSensitive
        case .critical:
            interruptionLevel = .critical
        }

        let payload = ... // Construct your notification payload here

        // Fetch all APNS devices from the database
        let devices = try await APNSDevice.query(on: context.application.db(.psql)).all()

        // Send the notification to each device
        for device in devices {
            let deviceToken = device.token
            do {
                try await context.application.apns.client.sendAlertNotification(
                    APNSAlertNotification(
                        alert: APNSAlertNotificationContent(
                            title: .raw("Announcement"),
                            subtitle: .raw(announcement.subject),
                            body: .raw(announcement.body),
                            launchImage: nil
                        ),
                        expiration: announcement.end, // Adjust the expiration based on the announcement's end date
                        priority: .immediately,
                        topic: Constants.apnsTopic,
                        payload: payload,
                        sound: .default,
                        mutableContent: 1,
                        interruptionLevel: interruptionLevel,
                        apnsID: announcement.id
                    ),
                    deviceToken: deviceToken
                )
            } catch {
                context.logger.error("Failed to send APNS notification: \(error)")
            }
        }
    }
}