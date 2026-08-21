#ifndef RUNNER_STARTUP_H_
#define RUNNER_STARTUP_H_

#include <string>
#include <vector>

void RegisterOronBoxUrlProtocol();
void RegisterOronBoxFileAssociations();
std::string OronBoxFilePathFromArguments(
    const std::vector<std::string>& arguments);

#endif  // RUNNER_STARTUP_H_
